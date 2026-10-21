class CreateJobApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :job_applications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :job_posting, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :status, null: false, default: "saved"

      t.timestamps
    end
    add_index :job_applications, %i[user_id status]

    create_table :job_application_events do |t|
      t.references :job_application, null: false, foreign_key: { on_delete: :cascade }
      t.string :from_status # nil for the event that created the application
      t.string :to_status, null: false
      t.text :note

      t.datetime :created_at, null: false
    end

    reversible do |direction|
      direction.up do
        # Every existing posting gets an application in the "saved" state.
        execute <<~SQL
          INSERT INTO job_applications (user_id, job_posting_id, status, created_at, updated_at)
          SELECT user_id, id, 'saved', created_at, created_at FROM job_postings;

          INSERT INTO job_application_events (job_application_id, from_status, to_status, created_at)
          SELECT id, NULL, 'saved', created_at FROM job_applications;
        SQL
      end
    end
  end
end
