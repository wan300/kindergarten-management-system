require "test_helper"
require "timeout"

class DeviceChatTurnsTest < ActionDispatch::IntegrationTest
  TOKEN = "test-bridge-token"

  def setup
    DeviceChatTurn.delete_all
    ChildChatMessage.delete_all
    ChildChatSession.delete_all
    ChildDevice.delete_all
    Student.delete_all
    Classroom.delete_all
    Teacher.delete_all
    teacher = Teacher.create!(first_name: "Ada", last_name: "Lovelace", career_name: "TR.ada", email: "ada-device@example.com", phone_number: "1111111122", gender: "female", password: "secret1")
    classroom = Classroom.create!(name: "Device Room", teacher: teacher)
    @student = Student.create!(first_name: "Noah", surname: "Brown", age: 3, admission_number: 2026901, classroom: classroom)
    @other_student = Student.create!(first_name: "Lily", surname: "King", age: 5, admission_number: 2026902, classroom: classroom)
    @device = ChildDevice.bind!(device_id: "Test-Device", student: @student)
    @old_token = ENV["XIAOZHI_BRIDGE_TOKEN"]
    ENV["XIAOZHI_BRIDGE_TOKEN"] = TOKEN
  end

  def teardown
    ENV["XIAOZHI_BRIDGE_TOKEN"] = @old_token
  end

  test "creates messages and returns the durable exchange" do
    fake = FakeDeepseek.new
    with_deepseek_client(fake) { post_turn }
    assert_response :created
    body = response.parsed_body
    assert_equal "t1", body["turn_id"]
    assert_equal "你好", body.dig("user_message", "content")
    assert_equal "device-model", body.dig("assistant_message", "model")
    assert_equal 2, ChildChatSession.find(body["chat_session_id"]).child_chat_messages.count
    assert_equal 1, fake.calls
  end

  test "replays matching completed input without a second model call" do
    fake = FakeDeepseek.new
    with_deepseek_client(fake) do
      post_turn
      first = response.parsed_body
      post_turn
      assert_response :ok
      assert_equal first, response.parsed_body
    end
    assert_equal 1, fake.calls
  end

  test "rejects bad authentication missing configuration and non-loopback peers" do
    post_turn(headers: { "Authorization" => "Bearer wrong", "REMOTE_ADDR" => "127.0.0.1" })
    assert_error :unauthorized, "invalid_token"
    ENV.delete("XIAOZHI_BRIDGE_TOKEN")
    post_turn
    assert_error :unauthorized, "bridge_not_configured"
    ENV["XIAOZHI_BRIDGE_TOKEN"] = TOKEN
    post_turn(headers: auth_headers.merge("REMOTE_ADDR" => "10.0.0.2", "X-Forwarded-For" => "127.0.0.1"))
    assert_error :forbidden, "loopback_required"
  end

  test "rejects unknown and disabled bindings" do
    post_turn(device_id: "missing")
    assert_error :not_found, "device_not_bound"
    @device.update!(enabled: false)
    post_turn
    assert_error :not_found, "device_not_bound"
  end

  test "validates exact JSON string inputs and lengths" do
    [{ device_id: 12 }, { session_id: "" }, { turn_id: "x" * 129 }, { content: "" }, { content: "x" * 4001 }].each do |invalid|
      post_turn(**invalid)
      assert_error :unprocessable_entity, "invalid_input"
    end
  end

  test "conflicts on mismatched replay input and held processing state" do
    fake = FakeDeepseek.new
    with_deepseek_client(fake) { post_turn }
    post_turn(content: "不同")
    assert_error :conflict, "turn_input_conflict"
    session = ChildChatSession.find_by!(child_device: @device, external_session_id: "s1", device_binding_epoch: @device.binding_epoch)
    session.device_chat_turns.create!(turn_id: "held", content: "busy", status: "processing", attempt_count: 1)
    post_turn(turn_id: "next")
    assert_error :conflict, "active_turn"
  end

  test "allows one explicit retry after model failure and reuses the user message" do
    failing = FakeDeepseek.new(error: true)
    with_deepseek_client(failing) { post_turn }
    assert_error :bad_gateway, "model_failure"
    turn = DeviceChatTurn.find_by!(turn_id: "t1")
    original_user_id = turn.user_message_id
    assert_equal "failed", turn.status
    success = FakeDeepseek.new
    with_deepseek_client(success) { post_turn }
    assert_response :created
    turn.reload
    assert_equal 2, turn.attempt_count
    assert_equal original_user_id, turn.user_message_id
    assert_equal 2, turn.child_chat_session.child_chat_messages.count
    turn.update!(status: "failed", assistant_message: nil)
    post_turn
    assert_error :conflict, "retry_exhausted"
  end

  test "does not automatically restart an ambiguous processing turn" do
    session = device_session
    user = session.child_chat_messages.create!(role: "user", content: "你好")
    session.device_chat_turns.create!(turn_id: "t1", content: "你好", status: "processing", attempt_count: 1, user_message: user)
    post_turn
    assert_error :conflict, "turn_processing"
  end

  test "rebind creates a new history even when the external session id is reused" do
    fake = FakeDeepseek.new
    with_deepseek_client(fake) { post_turn }
    old_session_id = response.parsed_body["chat_session_id"]
    ChildDevice.bind!(device_id: "test-device", student: @other_student)
    with_deepseek_client(fake) { post_turn(turn_id: "t2", content: "新的问题") }
    assert_response :created
    new_session = ChildChatSession.find(response.parsed_body["chat_session_id"])
    refute_equal old_session_id, new_session.id
    assert_equal @other_student.id, new_session.student_id
    new_call_messages = fake.received_messages.last
    assert_match(/Lily/, new_call_messages.first[:content])
    refute_match(/Noah/, new_call_messages.first[:content])
    refute new_call_messages.any? { |message| message[:content] == "你好" }
  end

  test "another child cannot access a device-created session" do
    with_deepseek_client(FakeDeepseek.new) { post_turn }
    session_id = response.parsed_body["chat_session_id"]

    get "/child/chat_sessions/#{session_id}", headers: child_headers(@other_student)
    assert_response :not_found
  end

  test "a failed turn cannot retry while another turn is processing" do
    session = device_session
    user = session.child_chat_messages.create!(role: "user", content: "first")
    session.device_chat_turns.create!(turn_id: "t1", content: "你好", status: "failed", attempt_count: 1, user_message: user)
    session.device_chat_turns.create!(turn_id: "held", content: "second", status: "processing", attempt_count: 1)
    fake = FakeDeepseek.new

    Timeout.timeout(1) { with_deepseek_client(fake) { post_turn } }

    assert_error :conflict, "active_turn"
    assert_equal 0, fake.calls
  end

  test "does not return a reply after the device is rebound during the model call" do
    fake = FakeDeepseek.new(on_chat: -> { ChildDevice.bind!(device_id: "test-device", student: @other_student) })

    with_deepseek_client(fake) { post_turn }

    assert_error :conflict, "binding_changed"
    old_session = ChildChatSession.find_by!(student: @student, external_session_id: "s1")
    assert_equal 2, old_session.child_chat_messages.count
    assert_equal "completed", old_session.device_chat_turns.find_by!(turn_id: "t1").status
    assert_empty @other_student.child_chat_sessions
  end

  test "does not replay a completed reply after the device is rebound" do
    fake = FakeDeepseek.new
    with_deepseek_client(fake) { post_turn }
    assert_response :created

    with_session_lookup_hook(-> { ChildDevice.bind!(device_id: "test-device", student: @other_student) }) do
      with_deepseek_client(fake) { post_turn }
    end

    assert_error :conflict, "binding_changed"
    assert_equal 1, fake.calls
    refute response.parsed_body.key?("assistant_message")
  end

  test "does not replay a completed reply after the device is disabled" do
    fake = FakeDeepseek.new
    with_deepseek_client(fake) { post_turn }
    assert_response :created

    with_session_lookup_hook(-> { @device.update!(enabled: false) }) do
      with_deepseek_client(fake) { post_turn }
    end

    assert_error :conflict, "binding_changed"
    assert_equal 1, fake.calls
    refute response.parsed_body.key?("assistant_message")
  end

  test "does not return a reply after the device is disabled during the model call" do
    fake = FakeDeepseek.new(on_chat: -> { @device.update!(enabled: false) })

    with_deepseek_client(fake) { post_turn }

    assert_error :conflict, "binding_changed"
    old_session = ChildChatSession.find_by!(student: @student, external_session_id: "s1")
    assert_equal 2, old_session.child_chat_messages.count
    assert_equal "completed", old_session.device_chat_turns.find_by!(turn_id: "t1").status
  end

  private

  FakeDeepseek = Struct.new(:error, :on_chat, :calls, :received_messages) do
    def initialize(error: false, on_chat: nil) = super(error, on_chat, 0, [])
    def chat(messages:)
      self.calls += 1
      received_messages << messages
      raise DeepseekClient::ApiError, "provider secret detail" if error
      raise "missing child context" unless messages.first[:content].match?(/Noah|Lily/)
      on_chat&.call
      { content: "我们一起试试吧！", model: "device-model", usage: { "prompt_tokens" => 4, "completion_tokens" => 5, "total_tokens" => 9 } }
    end
  end

  def post_turn(device_id: "test-device", session_id: "s1", turn_id: "t1", content: "你好", headers: auth_headers)
    post "/device/turns", params: { device_id: device_id, session_id: session_id, turn_id: turn_id, content: content }, headers: headers, as: :json
  end

  def auth_headers = { "Authorization" => "Bearer #{TOKEN}", "REMOTE_ADDR" => "127.0.0.1" }

  def child_headers(student)
    token = JWT.encode({ child_student_id: student.id }, ENV.fetch("JWT_SECRET"), "HS256")
    { "Authorization" => "Bearer #{token}" }
  end

  def assert_error(status, code)
    assert_response status
    assert_equal code, response.parsed_body["error"]
    refute_match(/secret detail|#{TOKEN}/, response.body)
  end

  def with_deepseek_client(client)
    original = DeepseekClient.method(:new)
    DeepseekClient.define_singleton_method(:new) { client }
    yield
  ensure
    DeepseekClient.define_singleton_method(:new, original)
  end

  def with_session_lookup_hook(hook)
    original = ChildChatSession.method(:find_or_create_by!)
    called = false
    ChildChatSession.define_singleton_method(:find_or_create_by!) do |*args, **kwargs, &block|
      unless called
        called = true
        hook.call
      end
      original.call(*args, **kwargs, &block)
    end
    yield
  ensure
    ChildChatSession.define_singleton_method(:find_or_create_by!, original)
  end

  def device_session
    ChildChatSession.create!(student: @student, child_device: @device, source: "device", external_session_id: "s1", device_binding_id: @device.binding_id, device_binding_epoch: @device.binding_epoch)
  end
end
