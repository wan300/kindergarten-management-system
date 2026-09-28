require "test_helper"
require "tempfile"

class GrowthRecordsTest < ActionDispatch::IntegrationTest
  SECRET = ENV.fetch("JWT_SECRET")

  class FakeGrowthRecordAnalysis
    def initialize(record)
      @record = record
    end

    def call
      note = @record.note.to_s
      positive = %w[开心 主动 分享 专注 独立].select { |word| note.include?(word) }
      watch = %w[焦虑 不吃 咳嗽].select { |word| note.include?(word) }
      {
        analysis: positive.any? || watch.any? ? "AI 识别到明确的成长观察线索。" : "未识别到足够清晰、可用于成长分析的内容。",
        positive_tags: positive,
        watch_tags: watch,
        model: "fake-deepseek-v4-flash",
        usage: {}
      }
    end
  end

  def setup
    @original_analysis_constructor = GrowthRecordAnalysis.method(:new)
    GrowthRecordAnalysis.define_singleton_method(:new) { |record| FakeGrowthRecordAnalysis.new(record) }
    GrowthRecord.destroy_all
    ParentStudent.delete_all
    Student.delete_all
    Classroom.delete_all
    Parent.delete_all
    Teacher.delete_all
    Admin.delete_all

    @teacher = Teacher.create!(
      first_name: "Ada", last_name: "Lovelace", career_name: "TR.growth",
      email: "growth-teacher@example.com", phone_number: "1111111111",
      gender: "female", password: "secret1"
    )
    @other_teacher = Teacher.create!(
      first_name: "Alan", last_name: "Turing", career_name: "TR.other-growth",
      email: "other-growth-teacher@example.com", phone_number: "2222222222",
      gender: "male", password: "secret2"
    )
    classroom = Classroom.create!(name: "Growth A", teacher: @teacher)
    other_classroom = Classroom.create!(name: "Growth B", teacher: @other_teacher)
    @student = Student.create!(
      first_name: "Grace", surname: "Hopper", age: 5,
      admission_number: 8801, classroom: classroom
    )
    @other_student = Student.create!(
      first_name: "Katherine", surname: "Johnson", age: 5,
      admission_number: 8802, classroom: other_classroom
    )
    @parent = Parent.create!(
      first_name: "Mary", last_name: "Hopper",
      phone_number: "3333333333", password: "secret3"
    )
    @admin = Admin.create!(
      first_name: "Grace", last_name: "Admin", email: "growth-admin@example.com", password: "secret4"
    )
    ParentStudent.create!(parent: @parent, student: @student, status: ParentStudent::APPROVED)
  end

  def teardown
    GrowthRecordAnalysis.define_singleton_method(:new, @original_analysis_constructor)
  end

  test "teacher and approved parent share dated observations while access stays scoped" do
    post "/growth_records",
      headers: teacher_headers(@teacher),
      params: { student_id: @student.id, recorded_on: (Date.current - 2.days).to_s, note: "今天很开心，主动分享玩具。" },
      as: :json
    assert_response :created
    created = JSON.parse(response.body)
    assert_equal "teacher", created["author_role"]
    assert_includes created["positive_tags"], "开心"
    assert_includes created["positive_tags"], "分享"

    get "/growth_records", headers: parent_headers(@parent), params: { student_id: @student.id }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [created["id"]], body["records"].map { |record| record["id"] }
    assert_equal "状态平稳", body.dig("summary", "status")

    get "/growth_records", headers: teacher_headers(@teacher), params: { student_id: @other_student.id }
    assert_response :not_found

    get "/growth_records", headers: parent_headers(@parent), params: { student_id: @other_student.id }
    assert_response :not_found
  end

  test "parent can upload an image and watch words update the summary" do
    image = Tempfile.new(["growth-record", ".png"])
    image.binmode
    image.write("not-a-real-image-but-valid-upload-by-content-type")
    image.rewind
    upload = Rack::Test::UploadedFile.new(image.path, "image/png", true, original_filename: "observation.png")

    post "/growth_records",
      headers: parent_headers(@parent),
      params: {
        student_id: @student.id,
        recorded_on: Date.current.to_s,
        note: "午睡前有点焦虑，也不吃午饭。",
        media: [upload]
      }
    assert_response :created
    created = JSON.parse(response.body)
    assert_equal "parent", created["author_role"]
    assert_equal "image/png", created.dig("media", 0, "content_type")
    assert_includes created["watch_tags"], "焦虑"
    assert_includes created["watch_tags"], "不吃"

    get "/growth_records", headers: teacher_headers(@teacher), params: { student_id: @student.id }
    assert_response :success
    assert_equal "建议关注", JSON.parse(response.body).dig("summary", "status")
  ensure
    image&.close!
  end

  test "admin can review and update any child's growth record" do
    post "/admin/growth_records",
      headers: admin_headers(@admin),
      params: { student_id: @student.id, recorded_on: "2026-09-01", note: "管理员记录：孩子很专注。" },
      as: :json
    assert_response :created
    admin_created = JSON.parse(response.body)
    assert_equal "admin", admin_created.fetch("author_role")

    post "/growth_records",
      headers: parent_headers(@parent),
      params: { student_id: @student.id, recorded_on: "2026-09-02", note: "今天很开心。" },
      as: :json
    assert_response :created
    record_id = JSON.parse(response.body).fetch("id")

    get "/admin/growth_records", headers: admin_headers(@admin), params: { student_id: @student.id }
    assert_response :success
    assert_equal [record_id, admin_created.fetch("id")], JSON.parse(response.body).fetch("records").map { |record| record.fetch("id") }

    patch "/admin/growth_records/#{record_id}",
      headers: admin_headers(@admin),
      params: { recorded_on: "2026-09-03", note: "管理员补充：今天主动分享玩具。" },
      as: :json
    assert_response :success
    updated = JSON.parse(response.body)
    assert_equal "2026-09-03", updated.fetch("recorded_on")
    assert_includes updated.fetch("positive_tags"), "主动"

    get "/growth_records", headers: parent_headers(@parent), params: { student_id: @student.id }
    assert_equal "2026-09-03", JSON.parse(response.body).fetch("records").first.fetch("recorded_on")
  end

  private

  def teacher_headers(teacher)
    { "Authorization" => "Bearer #{JWT.encode({ teacher_id: teacher.id }, SECRET)}" }
  end

  def parent_headers(parent)
    { "Authorization" => "Bearer #{JWT.encode({ parent_id: parent.id }, SECRET)}" }
  end

  def admin_headers(admin)
    { "Authorization" => "Bearer #{JWT.encode({ admin_id: admin.id }, SECRET)}" }
  end
end
