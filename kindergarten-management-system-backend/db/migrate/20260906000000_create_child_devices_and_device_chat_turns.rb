class CreateChildDevicesAndDeviceChatTurns < ActiveRecord::Migration[7.0]
  def change
    create_table :child_devices do |t|
      t.string :device_id, null: false
      t.references :student, null: false, foreign_key: true
      t.string :binding_id, null: false
      t.integer :binding_epoch, null: false, default: 1
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :child_devices, :device_id, unique: true
    add_index :child_devices, :binding_id, unique: true

    add_reference :child_chat_sessions, :child_device, foreign_key: true
    add_column :child_chat_sessions, :source, :string, null: false, default: "web"
    add_column :child_chat_sessions, :external_session_id, :string
    add_column :child_chat_sessions, :device_binding_id, :string
    add_column :child_chat_sessions, :device_binding_epoch, :integer
    add_index :child_chat_sessions,
      [:child_device_id, :device_binding_epoch, :external_session_id],
      unique: true,
      name: "index_child_chat_sessions_on_device_binding_and_external_id"

    create_table :device_chat_turns do |t|
      t.references :child_chat_session, null: false, foreign_key: true
      t.string :turn_id, null: false
      t.text :content, null: false
      t.string :status, null: false
      t.integer :attempt_count, null: false, default: 1
      t.references :user_message, foreign_key: { to_table: :child_chat_messages }
      t.references :assistant_message, foreign_key: { to_table: :child_chat_messages }
      t.timestamps
    end
    add_index :device_chat_turns, [:child_chat_session_id, :turn_id], unique: true
    add_index :device_chat_turns, [:child_chat_session_id, :status]
  end
end
