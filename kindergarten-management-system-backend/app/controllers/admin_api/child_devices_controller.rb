module AdminApi
  class ChildDevicesController < BaseController
    rescue_from ChildDeviceManagement::NotDiscovered, with: :not_discovered_response

    def index
      render json: ChildDeviceManagement.list, status: :ok
    end

    def bind
      values = binding_params
      return unless values

      result = ChildDeviceManagement.bind!(**values)
      render json: result.row, status: result.created ? :created : :ok
    end

    def disable
      render json: ChildDeviceManagement.disable!(id: params[:id]), status: :ok
    end

    def enable
      render json: ChildDeviceManagement.enable!(id: params[:id]), status: :ok
    end

    private

    def binding_params
      input = params.to_unsafe_h.slice("device_id", "student_id")
      device_id = input["device_id"]
      student_id = input["student_id"]
      valid_device = device_id.is_a?(String) && device_id.strip.present? && device_id.length <= 128
      valid_student = student_id.is_a?(Integer) || student_id.is_a?(String)
      valid_student &&= student_id.to_s.match?(/\A[1-9]\d*\z/)
      unless valid_device && valid_student
        render json: { error: "invalid_input" }, status: :unprocessable_entity
        return nil
      end

      { device_id: device_id, student_id: student_id.to_i }
    end

    def not_discovered_response
      render json: { error: "device_not_discovered" }, status: :not_found
    end
  end
end
