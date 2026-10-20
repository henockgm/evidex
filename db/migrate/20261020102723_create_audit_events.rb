class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :user, foreign_key: true # nil for events about unknown emails
      t.string :action, null: false
      t.string :ip_address
      t.string :user_agent
      t.jsonb :metadata, null: false, default: {}

      t.datetime :created_at, null: false
    end
    add_index :audit_events, %i[user_id created_at]
  end
end
