class CreateJobPostings < ActiveRecord::Migration[8.1]
  def change
    create_table :job_postings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :company, null: false
      t.string :location
      t.string :work_model # onsite, hybrid, remote
      t.date :deadline
      t.string :source_url
      t.text :description, null: false # the posting text as the user pasted or we fetched it

      t.timestamps
    end
    add_index :job_postings, %i[user_id created_at]
  end
end
