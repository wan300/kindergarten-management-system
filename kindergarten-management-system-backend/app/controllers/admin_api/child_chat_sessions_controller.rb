module AdminApi
  class ChildChatSessionsController < BaseController
    def index
      sessions = ChildChatSession
        .includes(:student, :parent, :child_chat_messages)
        .order(updated_at: :desc)
      sessions = sessions.where(student_id: params[:student_id]) if params[:student_id].present?
      if params[:device_id].present?
        device = ChildDevice.find_by(device_id: ChildDevice.normalize_id(params[:device_id]))
        sessions = device ? sessions.where(child_device_id: device.id) : sessions.none
      end

      render json: sessions, each_serializer: ChildChatSessionSerializer, status: :ok
    end

    def show
      session = ChildChatSession.includes(:student, :parent, :child_chat_messages).find(params[:id])
      render json: session, serializer: ChildChatSessionSerializer, status: :ok
    end
  end
end
