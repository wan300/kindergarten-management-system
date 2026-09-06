class LimitDeviceSessionsToOneProcessingTurn < ActiveRecord::Migration[7.0]
  def change
    add_index :device_chat_turns, :child_chat_session_id,
      unique: true,
      where: "status = 'processing'",
      name: "index_device_chat_turns_on_one_processing_per_session"
  end
end
