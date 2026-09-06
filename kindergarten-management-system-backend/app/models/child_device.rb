require "securerandom"

class ChildDevice < ApplicationRecord
  belongs_to :student
  has_many :child_chat_sessions, dependent: :restrict_with_error

  validates :device_id, presence: true, length: { maximum: 128 }, uniqueness: { case_sensitive: false }
  validates :binding_id, presence: true, uniqueness: true
  validates :binding_epoch, numericality: { only_integer: true, greater_than: 0 }

  before_validation :normalize_device_id

  def self.bind!(device_id:, student:)
    normalized = normalize_id(device_id)
    raise ActiveRecord::RecordInvalid.new(new) if normalized.blank? || normalized.length > 128

    transaction do
      device = lock.find_or_initialize_by(device_id: normalized)
      if device.persisted? && device.student_id == student.id
        device.update!(enabled: true) unless device.enabled?
      else
        device.student = student
        device.enabled = true
        device.binding_epoch = device.persisted? ? device.binding_epoch + 1 : 1
        device.binding_id = SecureRandom.uuid
        device.save!
      end
      device
    end
  end

  def self.normalize_id(value) = value.to_s.strip.downcase

  private

  def normalize_device_id
    self.device_id = self.class.normalize_id(device_id)
  end
end
