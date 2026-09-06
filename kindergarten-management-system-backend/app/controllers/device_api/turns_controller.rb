module DeviceApi
  class TurnsController < BaseController
    def create
      values = validated_values
      return unless values

      result = DeviceChatExchange.new.call(**values)
      turn = result.turn
      render json: {
        chat_session_id: turn.child_chat_session_id,
        turn_id: turn.turn_id,
        user_message: ChildChatReply.serialize(turn.user_message),
        assistant_message: ChildChatReply.serialize(turn.assistant_message)
      }, status: result.replayed ? :ok : :created
    rescue DeviceChatExchange::NotBound => error
      render_error(error.code, :not_found)
    rescue DeviceChatExchange::Conflict => error
      render_error(error.code, :conflict)
    rescue DeviceChatExchange::ModelFailure => error
      render_error(error.code, :bad_gateway)
    end

    private

    def validated_values
      input = params.to_unsafe_h.slice("device_id", "session_id", "turn_id", "content")
      ids_valid = %w[device_id session_id turn_id].all? { |key| input[key].is_a?(String) && input[key].strip.present? && input[key].length <= 128 }
      content_valid = input["content"].is_a?(String) && input["content"].length.between?(1, 4000) && input["content"].strip.present?
      return render_error("invalid_input", :unprocessable_entity) unless ids_valid && content_valid

      { device_id: input["device_id"], session_id: input["session_id"], turn_id: input["turn_id"], content: input["content"] }
    end

  end
end
