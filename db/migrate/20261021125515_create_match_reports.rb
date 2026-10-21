class CreateMatchReports < ActiveRecord::Migration[8.1]
  def change
    create_table :match_reports do |t|
      t.references :job_posting, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :version, null: false
      t.string :status, null: false, default: "pending" # pending, running, done, failed
      t.string :error
      t.string :model
      t.jsonb :strengths, null: false, default: []
      t.jsonb :gaps, null: false, default: []
      t.datetime :completed_at

      t.timestamps
    end
    add_index :match_reports, %i[job_posting_id version], unique: true

    create_table :requirement_matches do |t|
      t.references :match_report, null: false, foreign_key: { on_delete: :cascade }
      # Kept when the requirement is later edited or deleted; the text below is a snapshot.
      t.references :requirement, foreign_key: { on_delete: :nullify }
      t.string :requirement_kind, null: false
      t.text :requirement_text, null: false
      t.string :verdict, null: false # evidenced, transferable, gap
      t.text :reasoning
      t.integer :position, null: false

      t.timestamps
    end

    create_table :match_citations do |t|
      t.references :requirement_match, null: false, foreign_key: { on_delete: :cascade }
      # Snapshot of the cited passage: chunks are rebuilt when a document is read again.
      t.references :document_chunk, foreign_key: { on_delete: :nullify }
      t.references :document, foreign_key: { on_delete: :nullify }
      t.string :document_title, null: false
      t.integer :page
      t.string :section
      t.text :excerpt, null: false

      t.datetime :created_at, null: false
    end
  end
end
