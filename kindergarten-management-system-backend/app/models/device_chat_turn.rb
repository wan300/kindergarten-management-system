class DeviceChatTurn < ApplicationRecord
  PROCESSING = "processing"
  COMPLETED = "completed"
  FAILED = "failed"
  STATUSES = [PROCESSING, COMPLETED, FAILED].freeze

  belongs_to :child_chat_session
  belongs_to :user_message, class_name: "ChildChatMessage", optional: true
  belongs_to :assistant_message, class_name: "ChildChatMessage", optional: true

  validates :turn_id, presence: true, length: { maximum: 128 }, uniqueness: { scope: :child_chat_session_id }
  validates :content, presence: true, length: { maximum: 4000 }
  validates :status, inclusion: { in: STATUSES }
  validates :attempt_count, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 2 }
end
