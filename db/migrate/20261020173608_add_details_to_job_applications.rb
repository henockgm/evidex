class AddDetailsToJobApplications < ActiveRecord::Migration[8.1]
  def change
    change_table :job_applications, bulk: true do |t|
      t.date :applied_on
      t.string :next_action
      t.date :next_action_on
      t.text :notes
      t.jsonb :links, null: false, default: [] # [{ "label": "...", "url": "https://..." }]
    end
    add_index :job_applications, %i[user_id next_action_on]
  end
end
