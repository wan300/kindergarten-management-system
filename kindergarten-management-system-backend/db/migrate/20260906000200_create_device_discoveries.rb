class CreateDeviceDiscoveries < ActiveRecord::Migration[7.0]
  def change
    create_table :device_discoveries do |t|
      t.string :device_id, null: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end

    add_index :device_discoveries, :device_id, unique: true
  end
end
