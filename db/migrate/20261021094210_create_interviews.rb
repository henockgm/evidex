class CreateInterviews < ActiveRecord::Migration[8.1]
  def change
    create_table :interviews do |t|
      t.references :job_application, null: false, foreign_key: { on_delete: :cascade }
      t.string :round # e.g. "1st round", "Technical"
      t.datetime :scheduled_at, null: false
      t.string :format # video, phone, onsite, other
      t.string :location # address or meeting link
      t.string :status, null: false, default: "scheduled" # scheduled, completed, cancelled
      t.text :notes

      t.timestamps
    end
    add_index :interviews, %i[job_application_id scheduled_at]
    add_index :interviews, %i[status scheduled_at]
  end
end
