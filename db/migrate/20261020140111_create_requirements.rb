class CreateRequirements < ActiveRecord::Migration[8.1]
  def change
    create_table :requirements do |t|
      t.references :job_posting, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false # required, preferred, responsibility
      t.text :text, null: false
      t.integer :position, null: false

      t.timestamps
    end
    add_index :requirements, %i[job_posting_id kind position]
  end
end
