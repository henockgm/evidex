class AddTwoFactorToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :otp_secret          # encrypted (Active Record encryption)
      t.datetime :otp_enabled_at
      t.integer :otp_last_timestep  # last accepted code's time step, so a code can't be replayed
    end

    create_table :recovery_codes do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :code_digest, null: false
      t.datetime :used_at

      t.datetime :created_at, null: false
    end
    add_index :recovery_codes, :code_digest, unique: true
  end
end
