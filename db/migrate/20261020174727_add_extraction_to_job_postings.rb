class AddExtractionToJobPostings < ActiveRecord::Migration[8.1]
  def change
    change_table :job_postings, bulk: true do |t|
      t.string :employment_type # e.g. full-time, contract
      t.string :seniority
      t.string :salary # as stated in the ad, free text
      t.jsonb :keywords, null: false, default: []
      t.string :extraction_status, null: false, default: "none" # none, pending, done, failed
      t.string :extraction_error
      t.datetime :extracted_at
    end
  end
end
