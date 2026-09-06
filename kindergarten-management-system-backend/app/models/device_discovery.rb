class DeviceDiscovery < ApplicationRecord
  validates :device_id, presence: true, length: { maximum: 128 }, uniqueness: { case_sensitive: false }
  validates :first_seen_at, :last_seen_at, presence: true

  before_validation :normalize_device_id

  def self.observe!(device_id:, at: Time.current)
    normalized = ChildDevice.normalize_id(device_id)
    candidate = new(device_id: normalized, first_seen_at: at, last_seen_at: at)
    if normalized.blank? || normalized.length > 128
      candidate.valid?
      raise ActiveRecord::RecordInvalid.new(candidate)
    end

    transaction do
      discovery = lock.find_or_initialize_by(device_id: normalized)
      discovery.first_seen_at = [discovery.first_seen_at, at].compact.min
      discovery.last_seen_at = [discovery.last_seen_at, at].compact.max
      discovery.save!
      discovery
    end
  rescue ActiveRecord::RecordNotUnique
    discovery = find_by!(device_id: normalized)
    discovery.with_lock do
      discovery.first_seen_at = [discovery.first_seen_at, at].compact.min
      discovery.last_seen_at = [discovery.last_seen_at, at].compact.max
      discovery.save!
    end
    discovery
  end

  private

  def normalize_device_id
    self.device_id = ChildDevice.normalize_id(device_id)
  end
end
