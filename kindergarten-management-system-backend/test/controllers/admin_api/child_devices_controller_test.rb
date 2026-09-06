require "test_helper"

class AdminApi::ChildDevicesControllerTest < ActionDispatch::IntegrationTest
  SECRET = ENV.fetch("JWT_SECRET")

  def setup
    DeviceChatTurn.delete_all
    ChildChatMessage.delete_all
    ChildChatSession.delete_all
    ChildDevice.delete_all
    DeviceDiscovery.delete_all
    Student.delete_all
    Classroom.delete_all
    Parent.delete_all
    Teacher.delete_all
    Admin.delete_all

    @admin = Admin.create!(first_name: "Device", last_name: "Admin",
      email: "device-admin@example.com", phone_number: "1000000001", password: "admin123")
    @teacher = Teacher.create!(first_name: "Device", last_name: "Teacher", career_name: "TR.device",
      email: "device-teacher@example.com", phone_number: "1000000002", gender: "female", password: "secret1")
    @parent = Parent.create!(first_name: "Device", last_name: "Parent",
      phone_number: "1000000003", password: "secret1")
    @classroom = Classroom.create!(name: "Device Room", teacher: @teacher)
    @other_classroom = Classroom.create!(name: "Device Room Two")
    @student = Student.create!(first_name: "Ming", surname: "One", age: 4,
      admission_number: 9900801, classroom: @classroom)
    @other_student = Student.create!(first_name: "Hua", surname: "Two", age: 5,
      admission_number: 9900802, classroom: @other_classroom)
  end

  test "admin list merges pending enabled disabled and legacy bound devices" do
    DeviceDiscovery.observe!(device_id: "pending-board", at: 3.minutes.ago)
    DeviceDiscovery.observe!(device_id: "enabled-board", at: 2.minutes.ago)
    DeviceDiscovery.observe!(device_id: "disabled-board", at: 1.minute.ago)
    ChildDevice.bind!(device_id: "enabled-board", student: @student)
    ChildDevice.bind!(device_id: "disabled-board", student: @student).update!(enabled: false)
    ChildDevice.bind!(device_id: "legacy-board", student: @other_student)

    get "/admin/child_devices", headers: admin_headers

    assert_response :success
    rows = response.parsed_body.index_by { |row| row["device_id"] }
    assert_equal %w[disabled enabled enabled pending], rows.values.map { |row| row["status"] }.sort
    assert_equal "Ming One", rows["enabled-board"].dig("student", "name")
    assert_equal "Device Room", rows["enabled-board"].dig("classroom", "name")
    assert_nil rows["pending-board"]["student"]
    assert_nil rows["legacy-board"]["last_seen_at"]
  end

  test "admin binds a discovered device and repeated same child binding is a no-op" do
    DeviceDiscovery.observe!(device_id: "pending-board")

    post "/admin/child_devices/bind",
      params: { device_id: "pending-board", student_id: @student.id },
      headers: admin_headers,
      as: :json

    assert_response :created
    device = ChildDevice.find_by!(device_id: "pending-board")
    assert_equal @student.id, response.parsed_body.dig("student", "id")
    original_identity = [device.binding_id, device.binding_epoch]

    post "/admin/child_devices/bind",
      params: { device_id: "PENDING-BOARD", student_id: @student.id },
      headers: admin_headers,
      as: :json

    assert_response :success
    assert_equal original_identity, [device.reload.binding_id, device.binding_epoch]
    assert device.enabled?
  end

  test "admin rebind rotates identity and keeps old child session" do
    DeviceDiscovery.observe!(device_id: "shared-board")
    device = ChildDevice.bind!(device_id: "shared-board", student: @student)
    old_identity = [device.binding_id, device.binding_epoch]
    old_session = ChildChatSession.create!(student: @student, child_device: device, source: "device",
      external_session_id: "old-session", device_binding_id: device.binding_id,
      device_binding_epoch: device.binding_epoch)

    post "/admin/child_devices/bind",
      params: { device_id: "shared-board", student_id: @other_student.id },
      headers: admin_headers,
      as: :json

    assert_response :success
    device.reload
    assert_equal @other_student.id, device.student_id
    assert_not_equal old_identity, [device.binding_id, device.binding_epoch]
    assert_equal @student.id, old_session.reload.student_id
    assert_equal @student.id, old_session.child_device.child_chat_sessions.find(old_session.id).student_id
  end

  test "admin disables and enables without rotating binding" do
    DeviceDiscovery.observe!(device_id: "toggle-board")
    device = ChildDevice.bind!(device_id: "toggle-board", student: @student)
    original_identity = [device.binding_id, device.binding_epoch]

    patch "/admin/child_devices/#{device.id}/disable", headers: admin_headers
    assert_response :success
    assert_equal "disabled", response.parsed_body["status"]
    assert_not device.reload.enabled?

    patch "/admin/child_devices/#{device.id}/enable", headers: admin_headers
    assert_response :success
    assert_equal "enabled", response.parsed_body["status"]
    assert device.reload.enabled?
    assert_equal original_identity, [device.binding_id, device.binding_epoch]
  end

  test "management rejects unknown resources and invalid binding input" do
    post "/admin/child_devices/bind",
      params: { device_id: "not-discovered", student_id: @student.id },
      headers: admin_headers,
      as: :json
    assert_response :not_found

    DeviceDiscovery.observe!(device_id: "pending-board")
    post "/admin/child_devices/bind",
      params: { device_id: "pending-board", student_id: 999_999 },
      headers: admin_headers,
      as: :json
    assert_response :not_found

    post "/admin/child_devices/bind",
      params: { device_id: 12, student_id: @student.id },
      headers: admin_headers,
      as: :json
    assert_response :unprocessable_entity

    patch "/admin/child_devices/999999/disable", headers: admin_headers
    assert_response :not_found
  end

  test "only administrator can access device management" do
    get "/admin/child_devices"
    assert_response :unauthorized

    get "/admin/child_devices", headers: teacher_headers
    assert_response :forbidden

    get "/admin/child_devices", headers: parent_headers
    assert_response :forbidden

    get "/admin/child_devices", headers: child_headers
    assert_response :forbidden
  end

  test "admin and teacher cannot delete a student with an enabled or disabled device" do
    device = ChildDevice.bind!(device_id: "retained-board", student: @student)
    ParentStudent.create!(parent: @parent, student: @student, status: ParentStudent::APPROVED)
    session = ChildChatSession.create!(student: @student)
    session.child_chat_messages.create!(role: "user", content: "Keep this web history")

    [true, false].each do |enabled|
      device.update!(enabled: enabled)
      student_delete_requests.each do |path, headers|
        assert_no_difference ["Student.count", "ChildDevice.count", "ParentStudent.count", "ChildChatSession.count", "ChildChatMessage.count"] do
          delete path, headers: headers
          assert_response :conflict
          assert_includes response.parsed_body["error"], "改绑或解绑"
        end
      end
    end
  end

  test "admin and teacher preserve the former student's device history after rebind" do
    device = ChildDevice.bind!(device_id: "history-board", student: @student)
    session = ChildChatSession.create!(student: @student, child_device: device, source: "device")
    message = session.child_chat_messages.create!(role: "user", content: "Keep this device history")
    session.device_chat_turns.create!(turn_id: "history-turn", content: message.content, status: "failed", user_message: message)
    ChildDevice.bind!(device_id: device.device_id, student: @other_student)

    student_delete_requests.each do |path, headers|
      assert_no_difference ["Student.count", "ChildDevice.count", "ChildChatSession.count", "ChildChatMessage.count", "DeviceChatTurn.count"] do
        delete path, headers: headers
        assert_response :conflict
        assert_includes response.parsed_body["error"], "设备聊天历史"
      end
    end
    assert_equal @other_student.id, device.reload.student_id
  end

  test "admin and teacher can still delete students with only web history" do
    student_delete_requests.each do |path, headers|
      Student.transaction(requires_new: true) do
        session = ChildChatSession.create!(student: @student)
        session.child_chat_messages.create!(role: "user", content: "Ordinary web history")
        assert_difference "Student.count", -1 do
          delete path, headers: headers
          assert_response :no_content
        end
        refute ChildChatSession.exists?(session.id)
        raise ActiveRecord::Rollback
      end
    end
  end

  private

  def student_delete_requests
    [["/admin/students/#{@student.id}", admin_headers], ["/students/#{@student.id}", teacher_headers]]
  end

  def admin_headers
    { "Authorization" => "Bearer #{JWT.encode({ admin_id: @admin.id }, SECRET)}" }
  end

  def teacher_headers
    { "Authorization" => "Bearer #{JWT.encode({ teacher_id: @teacher.id }, SECRET)}" }
  end

  def parent_headers
    { "Authorization" => "Bearer #{JWT.encode({ parent_id: @parent.id }, SECRET)}" }
  end

  def child_headers
    { "Authorization" => "Bearer #{JWT.encode({ child_student_id: @student.id }, SECRET)}" }
  end
end
