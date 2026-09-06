module ChildApi
  class ChatMessagesController < BaseController
    def create
      session = accessible_chat_session(params[:chat_session_id])
      if session.source == "device"
        render json: { error: "设备聊天记录仅供查看，请新建网页会话后发送消息。" }, status: :conflict
        return
      end
      content = params[:content].to_s.strip

      if content.blank?
        render json: { error: "Message content is required" }, status: :unprocessable_entity
        return
      end

      result = ChildChatReply.new.call(session: session, content: content)

      render json: {
        user_message: ChildChatReply.serialize(result.user_message),
        assistant_message: ChildChatReply.serialize(result.assistant_message)
      }, status: :created
    rescue DeepseekClient::Error => e
      render json: { error: e.message }, status: :bad_gateway
    end

  end
end
