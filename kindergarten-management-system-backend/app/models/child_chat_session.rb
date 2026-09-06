class ChildChatSession < ApplicationRecord
  belongs_to :student
  belongs_to :parent, optional: true
  belongs_to :child_device, optional: true
  has_many :child_chat_messages, -> { order(:created_at) }, dependent: :destroy
  has_many :device_chat_turns, dependent: :destroy

  validates :student, presence: true
  validates :source, inclusion: { in: %w[web device] }

  before_validation :set_default_title, on: :create

  private

  def set_default_title
    self.title = "儿童陪伴对话" if title.blank?
  end
end
