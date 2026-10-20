class CreateAiUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_usages do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :feature, null: false # e.g. posting_extraction
      t.string :model, null: false
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.integer :latency_ms
      t.boolean :succeeded, null: false, default: true

      t.datetime :created_at, null: false
    end
    add_index :ai_usages, %i[user_id feature created_at]
  end
end
