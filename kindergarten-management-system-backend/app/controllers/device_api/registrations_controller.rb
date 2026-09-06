module DeviceApi
  class RegistrationsController < BaseController
    def create
      device_id = validated_device_id
      return unless device_id

      discovery = DeviceDiscovery.observe!(device_id: device_id)
      device = ChildDevice.find_by(device_id: discovery.device_id)
      status = if device.nil?
        "pending"
      elsif device.enabled?
        "enabled"
      else
        "disabled"
      end

      render json: { device_id: discovery.device_id, status: status }, status: :ok
    rescue ActiveRecord::RecordInvalid
      render_error("invalid_input", :unprocessable_entity)
    end

    private

    def validated_device_id
      value = params.to_unsafe_h["device_id"]
      return render_error("invalid_input", :unprocessable_entity) unless value.is_a?(String)
      return render_error("invalid_input", :unprocessable_entity) unless value.strip.present? && value.length <= 128

      value
    end
  end
end
