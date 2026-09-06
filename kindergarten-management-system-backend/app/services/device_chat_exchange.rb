class DeviceChatExchange
  class Error < StandardError
    attr_reader :code
    def initialize(code)
      @code = code
      super(code)
    end
  end
  class NotBound < Error; end
  class Conflict < Error; end
  class ModelFailure < Error; end

  Result = Struct.new(:turn, :replayed, keyword_init: true)

  def initialize(reply: ChildChatReply.new)
    @reply = reply
  end

  def call(device_id:, session_id:, turn_id:, content:)
    device = ChildDevice.find_by(device_id: ChildDevice.normalize_id(device_id), enabled: true)
    raise NotBound, "device_not_bound" unless device

    session = find_or_create_session(device, session_id)
    reservation = reserve(session, turn_id, content)
    return reservation if reservation.replayed

    begin
      reply = @reply.call(session: session, content: content, user_message: reservation.turn.user_message)
      reservation.turn.update!(status: DeviceChatTurn::COMPLETED, assistant_message: reply.assistant_message)
      Result.new(turn: reservation.turn.reload, replayed: false)
    rescue DeepseekClient::Error
      reservation.turn.update!(status: DeviceChatTurn::FAILED)
      raise ModelFailure, "model_failure"
    end
  end

  private

  def find_or_create_session(device, external_id)
    ChildChatSession.find_or_create_by!(
      child_device: device,
      device_binding_id: device.binding_id,
      device_binding_epoch: device.binding_epoch,
      external_session_id: external_id
    ) do |session|
      session.student = device.student
      session.source = "device"
      session.title = "设备陪伴对话"
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def reserve(session, turn_id, content)
    session.with_lock do
      turn = session.device_chat_turns.find_by(turn_id: turn_id)
      if turn
        raise Conflict, "turn_input_conflict" unless turn.content == content
        next replay(turn) if turn.status == DeviceChatTurn::COMPLETED
        raise Conflict, "turn_processing" if turn.status == DeviceChatTurn::PROCESSING
        raise Conflict, "invalid_retry_state" unless turn.status == DeviceChatTurn::FAILED && turn.user_message.present?
        raise Conflict, "retry_exhausted" if turn.attempt_count >= 2

        turn.update!(status: DeviceChatTurn::PROCESSING, attempt_count: turn.attempt_count + 1)
        next Result.new(turn: turn, replayed: false)
      elsif session.device_chat_turns.where(status: DeviceChatTurn::PROCESSING).exists?
        raise Conflict, "active_turn"
      end

      user = session.child_chat_messages.create!(role: ChildChatMessage::USER, content: content)
      turn = session.device_chat_turns.create!(turn_id: turn_id, content: content, status: DeviceChatTurn::PROCESSING, attempt_count: 1, user_message: user)
      Result.new(turn: turn, replayed: false)
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def replay(turn)
    raise Conflict, "invalid_retry_state" unless turn.user_message && turn.assistant_message
    Result.new(turn: turn, replayed: true)
  end
end
