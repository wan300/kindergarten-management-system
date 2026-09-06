require "test_helper"

class DeviceRegistrationsTest < ActionDispatch::IntegrationTest
  TOKEN = "bridge-test-token-at-least-thirty-two-characters"

  def setup
    @old_token = ENV["XIAOZHI_BRIDGE_TOKEN"]
    ENV["XIAOZHI_BRIDGE_TOKEN"] = TOKEN
    DeviceChatTurn.delete_all
    ChildChatSession.delete_all
    ChildDevice.delete_all
    DeviceDiscovery.delete_all if defined?(DeviceDiscovery)
    Student.delete_all
    Classroom.delete_all
    @classroom = Classroom.create!(name: "Discovery Room")
    @student = Student.create!(first_name: "Lin", surname: "Test", age: 4,
      admission_number: 9900701, classroom: @classroom)
  end

  def teardown
    ENV["XIAOZHI_BRIDGE_TOKEN"] = @old_token
  end

  test "registration observes pending device without exposing child data" do
    post_registration(device_id: " New-Board ")

    assert_response :success
    assert_equal({ "device_id" => "new-board", "status" => "pending" }, response.parsed_body)
    assert_not response.body.include?("student")
    assert_equal 1, DeviceDiscovery.count
  end

  test "registration reports enabled and disabled bindings" do
    ChildDevice.bind!(device_id: "known-board", student: @student)

    post_registration(device_id: "KNOWN-BOARD")
    assert_response :success
    assert_equal "enabled", response.parsed_body["status"]

    ChildDevice.find_by!(device_id: "known-board").update!(enabled: false)
    post_registration(device_id: "known-board")
    assert_response :success
    assert_equal "disabled", response.parsed_body["status"]
  end

  test "registration is idempotent and refreshes last seen" do
    travel_to Time.zone.parse("2026-09-06 10:00:00") do
      post_registration(device_id: "repeat-board")
      assert_response :success
    end
    first_seen = DeviceDiscovery.find_by!(device_id: "repeat-board").first_seen_at

    travel_to Time.zone.parse("2026-09-06 10:05:00") do
      post_registration(device_id: "repeat-board")
      assert_response :success
    end

    discovery = DeviceDiscovery.find_by!(device_id: "repeat-board")
    assert_equal first_seen, discovery.first_seen_at
    assert_equal Time.zone.parse("2026-09-06 10:05:00"), discovery.last_seen_at
    assert_equal 1, DeviceDiscovery.where(device_id: "repeat-board").count
  end

  test "registration rejects invalid input" do
    [nil, 12, "", " ", "x" * 129].each do |device_id|
      post_registration(device_id: device_id)
      assert_response :unprocessable_entity
      assert_equal "invalid_input", response.parsed_body["error"]
    end
  end

  test "registration requires configured valid token and loopback peer" do
    post_registration(device_id: "board", token: "wrong")
    assert_response :unauthorized
    assert_equal "invalid_token", response.parsed_body["error"]

    ENV["XIAOZHI_BRIDGE_TOKEN"] = ""
    post_registration(device_id: "board")
    assert_response :unauthorized
    assert_equal "bridge_not_configured", response.parsed_body["error"]

    ENV["XIAOZHI_BRIDGE_TOKEN"] = TOKEN
    post_registration(device_id: "board", remote_addr: "192.168.1.10")
    assert_response :forbidden
    assert_equal "loopback_required", response.parsed_body["error"]
  end

  private

  def post_registration(device_id:, token: TOKEN, remote_addr: "127.0.0.1")
    post "/device/registration",
      params: { device_id: device_id },
      headers: { "Authorization" => "Bearer #{token}", "REMOTE_ADDR" => remote_addr },
      as: :json
  end
end
