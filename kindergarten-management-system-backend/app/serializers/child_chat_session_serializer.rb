class ChildChatSessionSerializer < ActiveModel::Serializer
  attributes :id,
    :title,
    :student_id,
    :student_name,
    :parent_id,
    :parent_name,
    :source,
    :device_id,
    :created_at,
    :updated_at

  has_many :child_chat_messages, key: :messages

  def student_name
    [object.student.first_name, object.student.second_name, object.student.surname].filter_map(&:presence).join(" ")
  end

  def parent_name
    return unless object.parent

    [object.parent.first_name, object.parent.last_name].filter_map(&:presence).join(" ")
  end

  def device_id
    object.child_device&.device_id
  end
end
