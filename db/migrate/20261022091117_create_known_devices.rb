# Browsers a user has signed in from, recognised by a long-lived device cookie
# (only its SHA-256 digest is stored). A sign-in from an unknown one is emailed.
class CreateKnownDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :known_devices do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :device_digest, null: false
      t.string :user_agent
      t.string :ip_address
      t.datetime :last_seen_at, null: false
      t.timestamps
    end
    add_index :known_devices, %i[user_id device_digest], unique: true
  end
end
