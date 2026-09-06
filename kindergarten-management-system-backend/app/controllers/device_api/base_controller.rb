require "ipaddr"

module DeviceApi
  class BaseController < ActionController::API
    before_action :require_loopback
    before_action :authenticate_bridge

    private

    def require_loopback
      address = IPAddr.new(request.remote_addr)
      render_error("loopback_required", :forbidden) unless address.loopback?
    rescue IPAddr::InvalidAddressError
      render_error("loopback_required", :forbidden)
    end

    def authenticate_bridge
      expected = ENV["XIAOZHI_BRIDGE_TOKEN"].to_s
      return render_error("bridge_not_configured", :unauthorized) if expected.blank?

      supplied = request.authorization.to_s.match(/\ABearer (.+)\z/)&.captures&.first.to_s
      valid = supplied.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(supplied, expected)
      render_error("invalid_token", :unauthorized) unless valid
    end

    def render_error(code, status)
      render json: { error: code }, status: status
      nil
    end
  end
end
