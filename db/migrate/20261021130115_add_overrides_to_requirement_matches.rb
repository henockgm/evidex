class AddOverridesToRequirementMatches < ActiveRecord::Migration[8.1]
  def change
    change_table :requirement_matches, bulk: true do |t|
      t.string :user_verdict # the user's own call; the AI's stays in `verdict`
      t.text :user_note
    end
  end
end
