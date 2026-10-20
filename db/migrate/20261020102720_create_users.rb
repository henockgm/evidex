class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :name
      t.string :password_digest # nil for accounts that only use Google/Microsoft sign-in
      t.datetime :email_verified_at
      t.integer :failed_sign_in_count, null: false, default: 0
      t.integer :lockout_count, null: false, default: 0
      t.datetime :locked_until

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
