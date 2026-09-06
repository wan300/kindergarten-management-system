require "test_helper"
require "tempfile"

class ChildLearningTest < ActionDispatch::IntegrationTest
  SECRET = ENV.fetch("JWT_SECRET")

  def setup
    ChildTtsAudio.delete_all if defined?(ChildTtsAudio)
    ChildChatMessage.delete_all if defined?(ChildChatMessage)
    ChildChatSession.delete_all if defined?(ChildChatSession)
    DeviceChatTurn.delete_all if defined?(DeviceChatTurn)
    ChildDevice.delete_all if defined?(ChildDevice)
    DeviceDiscovery.delete_all if defined?(DeviceDiscovery)
    EducationalVideo.delete_all if defined?(EducationalVideo)
    ParentStudent.delete_all
    Discipline.delete_all
    Attendance.delete_all
    Student.delete_all
    Classroom.delete_all
    Parent.delete_all
    Teacher.delete_all
    Admin.delete_all

    @admin = Admin.create!(
      first_name: "System",
      last_name: "Admin",
      email: "admin@example.com",
      phone_number: "0000000000",
      password: "admin123"
    )
    @teacher = Teacher.create!(
      first_name: "Ada",
      last_name: "Lovelace",
      career_name: "TR.ada",
      email: "ada@example.com",
      phone_number: "1111111111",
      gender: "female",
      password: "secret1"
    )
    @classroom = Classroom.create!(name: "Sunflower A", teacher: @teacher)
    @student = Student.create!(
      first_name: "Noah",
      second_name: "Demo",
      surname: "Brown",
      age: 3,
      description: "Curious learner",
      admission_number: 2026001,
      classroom: @classroom
    )
    @older_student = Student.create!(
      first_name: "Lily",
      second_name: "Demo",
      surname: "King",
      age: 5,
      description: "Creative learner",
      admission_number: 2026002,
      classroom: @classroom
    )
    @parent = Parent.create!(first_name: "Paul", last_name: "Brown", phone_number: "1390002001", password: "123456")
    @other_parent = Parent.create!(first_name: "Ivy", last_name: "Brown", phone_number: "1390002002", password: "123456")
    ParentStudent.create!(parent: @parent, student: @student, status: ParentStudent::APPROVED)
    ParentStudent.create!(parent: @other_parent, student: @older_student, status: ParentStudent::APPROVED)
  end

  test "admin manages educational videos and child endpoint returns all published videos with subject filtering" do
    post "/admin/educational_videos",
      headers: admin_headers(@admin),
      params: video_params(title: "Counting Song", subject: "数学", status: EducationalVideo::DRAFT)
    assert_response :created
    draft_video = JSON.parse(response.body)

    get "/child/videos", headers: child_headers(@student)
    assert_response :success
    assert_equal [], JSON.parse(response.body)

    patch "/admin/educational_videos/#{draft_video["id"]}",
      headers: admin_headers(@admin),
      params: { status: EducationalVideo::PUBLISHED }
    assert_response :success

    post "/admin/educational_videos",
      headers: admin_headers(@admin),
      params: video_params(title: "Big Kids Reading", subject: "语言", min_age: 5, max_age: 6, status: EducationalVideo::PUBLISHED)
    assert_response :created

    get "/child/videos", headers: child_headers(@student)
    assert_response :success
    videos = JSON.parse(response.body)
    assert_equal ["Counting Song", "Big Kids Reading"].sort, videos.map { |video| video["title"] }.sort

    get "/child/videos", headers: child_headers(@student), params: { subject: "数学" }
    assert_response :success
    videos = JSON.parse(response.body)
    assert_equal ["Counting Song"], videos.map { |video| video["title"] }
    assert videos.first["video_url"].present?

    get "/child/videos", headers: parent_headers(@parent)
    assert_response :forbidden

    get "/admin/educational_videos", headers: teacher_headers(@teacher)
    assert_response :forbidden
  end

  test "child login and chat endpoints use independent child token" do
    post "/child_login", params: { admission_number: @student.admission_number, password: Student::DEFAULT_CHILD_PASSWORD }, as: :json
    assert_response :accepted
    child_login = JSON.parse(response.body)
    assert child_login["jwt"].present?
    assert_equal @student.id, child_login.dig("student", "id")

    post "/child_login", params: { admission_number: @student.admission_number, password: "wrong-password" }, as: :json
    assert_response :unauthorized

    fake_client = Class.new do
      def chat(messages:)
        raise "missing child context" unless messages.first[:content].include?("Noah")

        {
          content: "我们一起数一数吧：一、二、三。你能找到三个玩具吗？",
          model: "deepseek-v4-flash",
          usage: { "prompt_tokens" => 10, "completion_tokens" => 12, "total_tokens" => 22 }
        }
      end
    end.new

    with_deepseek_client(fake_client) do
      post "/child/chat_sessions",
        headers: { "Authorization" => "Bearer #{child_login["jwt"]}" },
        params: { title: "数学陪伴" },
        as: :json
      assert_response :created
      session_id = JSON.parse(response.body)["id"]

      post "/child/chat_sessions/#{session_id}/messages",
        headers: { "Authorization" => "Bearer #{child_login["jwt"]}" },
        params: { content: "我想学数数" },
        as: :json
      assert_response :created
      body = JSON.parse(response.body)
      assert_equal "我想学数数", body.dig("user_message", "content")
      assert_equal "deepseek-v4-flash", body.dig("assistant_message", "model")
    end

    get "/child/chat_sessions", headers: parent_headers(@parent)
    assert_response :forbidden

    get "/child/chat_sessions/#{ChildChatSession.first.id}", headers: child_headers(@older_student)
    assert_response :not_found

    get "/admin/child_chat_sessions", headers: admin_headers(@admin)
    assert_response :success
    sessions = JSON.parse(response.body)
    assert_equal 1, sessions.length
    assert_equal 2, sessions.first["messages"].length
  end

  test "parent supervision APIs expose approved children and allow password reset" do
    session = ChildChatSession.create!(student: @student, title: "亲子监管")
    session.child_chat_messages.create!(role: ChildChatMessage::USER, content: "你好")

    get "/parent/children", headers: parent_headers(@parent)
    assert_response :success
    children = JSON.parse(response.body)
    assert_equal [@student.id], children.map { |child| child["id"] }

    get "/parent/children/#{@student.id}/chat_sessions", headers: parent_headers(@parent)
    assert_response :success
    sessions = JSON.parse(response.body)
    assert_equal ["亲子监管"], sessions.map { |item| item["title"] }

    get "/parent/children/#{@student.id}/chat_sessions", headers: child_headers(@student)
    assert_response :forbidden

    patch "/parent/children/#{@student.id}/password",
      headers: parent_headers(@parent),
      params: { password: "654321" },
      as: :json
    assert_response :success

    post "/child_login", params: { admission_number: @student.admission_number, password: Student::DEFAULT_CHILD_PASSWORD }, as: :json
    assert_response :unauthorized

    post "/child_login", params: { admission_number: @student.admission_number, password: "654321" }, as: :json
    assert_response :accepted

    patch "/parent/children/#{@student.id}/password",
      headers: parent_headers(@other_parent),
      params: { password: "777777" },
      as: :json
    assert_response :not_found
  end

  test "admin filters child chat sessions by normalized device id" do
    first_device = ChildDevice.bind!(device_id: "Board-A", student: @student)
    second_device = ChildDevice.bind!(device_id: "board-b", student: @older_student)
    ChildChatSession.create!(student: @student, title: "网页记录")
    ChildChatSession.create!(student: @student, child_device: first_device, source: "device",
      external_session_id: "a1", device_binding_id: first_device.binding_id,
      device_binding_epoch: first_device.binding_epoch)
    ChildChatSession.create!(student: @older_student, child_device: second_device, source: "device",
      external_session_id: "b1", device_binding_id: second_device.binding_id,
      device_binding_epoch: second_device.binding_epoch)

    get "/admin/child_chat_sessions", params: { device_id: " BOARD-A " }, headers: admin_headers(@admin)
    assert_response :success
    assert_equal ["board-a"], response.parsed_body.map { |session| session["device_id"] }

    get "/admin/child_chat_sessions", params: { device_id: "unknown" }, headers: admin_headers(@admin)
    assert_response :success
    assert_equal [], response.parsed_body
  end

  test "chat endpoint returns clear error when DeepSeek fails" do
    session = ChildChatSession.create!(student: @student)
    fake_client = Class.new do
      def chat(messages:)
        raise DeepseekClient::ApiError, "DeepSeek unavailable"
      end
    end.new

    with_deepseek_client(fake_client) do
      post "/child/chat_sessions/#{session.id}/messages",
        headers: child_headers(@student),
        params: { content: "你好" },
        as: :json
      assert_response :bad_gateway
      assert_equal "DeepSeek unavailable", JSON.parse(response.body)["error"]
    end

    assert_equal 1, session.child_chat_messages.count
    assert_equal ChildChatMessage::USER, session.child_chat_messages.first.role
  end

  test "child tts endpoint requires child token and returns synthesized audio" do
    fake_client = Class.new do
      attr_reader :received_text

      def synthesize(text:)
        @received_text = text
        {
          provider: "tencent_cloud",
          voice_type: 101_016,
          codec: "mp3",
          sample_rate: 16_000,
          segments: [{ audio_base64: "audio-data" }]
        }
      end
    end.new

    post "/child/tts", params: { text: "你好" }, as: :json
    assert_response :unauthorized

    post "/child/tts", headers: parent_headers(@parent), params: { text: "你好" }, as: :json
    assert_response :forbidden

    with_tencent_tts_client(fake_client) do
      post "/child/tts",
        headers: child_headers(@student),
        params: { text: "你好😊" },
        as: :json
      assert_response :success
    end

    body = JSON.parse(response.body)
    assert_equal "你好😊", fake_client.received_text
    assert_equal "tencent_cloud", body["provider"]
    assert_equal 101_016, body["voice_type"]
    assert_equal "mp3", body["codec"]
    assert_equal "audio-data", body.dig("segments", 0, "audio_base64")
  end

  test "child tts endpoint persists generated audio and reuses it for the same assistant message" do
    session = @student.child_chat_sessions.create!(title: "TTS cache test")
    assistant_message = session.child_chat_messages.create!(
      role: ChildChatMessage::ASSISTANT,
      content: "cache me please"
    )
    fake_client = Class.new do
      attr_reader :received_text, :calls

      def synthesize(text:)
        @calls = @calls.to_i + 1
        @received_text = text
        {
          provider: "tencent_cloud",
          voice_type: 101_016,
          codec: "mp3",
          sample_rate: 16_000,
          segments: [{ audio_base64: "audio-data" }]
        }
      end
    end.new

    with_tencent_tts_client(fake_client) do
      post "/child/tts",
        headers: child_headers(@student),
        params: { text: "ignored", message_id: assistant_message.id },
        as: :json
      assert_response :success
      first_body = JSON.parse(response.body)
      assert_equal false, first_body["cached"]

      post "/child/tts",
        headers: child_headers(@student),
        params: { text: "ignored", message_id: assistant_message.id },
        as: :json
      assert_response :success
    end

    body = JSON.parse(response.body)
    assert_equal "cache me please", fake_client.received_text
    assert_equal 1, fake_client.calls
    assert_equal 1, ChildTtsAudio.count
    assert_equal true, body["cached"]
    assert_equal "audio-data", body.dig("segments", 0, "audio_base64")
  end

  test "child tts endpoint returns safe errors without exposing provider details" do
    fake_client = Class.new do
      def synthesize(text:)
        raise TencentTtsClient::ApiError, "AI 回复中包含无法朗读的内容"
      end
    end.new

    with_tencent_tts_client(fake_client) do
      post "/child/tts",
        headers: child_headers(@student),
        params: { text: "你好😊" },
        as: :json
      assert_response :bad_gateway
    end

    body = JSON.parse(response.body)
    assert_equal "AI 回复中包含无法朗读的内容", body["error"]
    refute_match(/secret|signature|authorization/i, body["error"])
  end

  private

  def video_params(overrides = {})
    {
      title: "Animal Story",
      description: "A short early education video",
      stage: "小班",
      level: "入门",
      subject: "语言",
      min_age: 3,
      max_age: 4,
      status: EducationalVideo::PUBLISHED,
      video_file: uploaded_video
    }.merge(overrides)
  end

  def uploaded_video
    file = Tempfile.new(["education-video", ".mp4"])
    file.binmode
    file.write("fake video content")
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "video/mp4", original_filename: "lesson.mp4")
  end

  def admin_headers(admin)
    { "Authorization" => "Bearer #{JWT.encode({ admin_id: admin.id }, SECRET)}" }
  end

  def teacher_headers(teacher)
    { "Authorization" => "Bearer #{JWT.encode({ teacher_id: teacher.id }, SECRET)}" }
  end

  def parent_headers(parent)
    { "Authorization" => "Bearer #{JWT.encode({ parent_id: parent.id }, SECRET)}" }
  end

  def child_headers(student)
    { "Authorization" => "Bearer #{JWT.encode({ child_student_id: student.id }, SECRET)}" }
  end

  def with_deepseek_client(client)
    original_new = DeepseekClient.method(:new)
    DeepseekClient.define_singleton_method(:new) { client }
    yield
  ensure
    DeepseekClient.define_singleton_method(:new, original_new)
  end

  def with_tencent_tts_client(client)
    original_new = TencentTtsClient.method(:new)
    TencentTtsClient.define_singleton_method(:new) { client }
    yield
  ensure
    TencentTtsClient.define_singleton_method(:new, original_new)
  end

end
