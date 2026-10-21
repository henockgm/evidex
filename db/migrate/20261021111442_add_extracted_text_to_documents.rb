class AddExtractedTextToDocuments < ActiveRecord::Migration[8.1]
  def change
    change_table :documents, bulk: true do |t|
      # Text per page for PDFs; a single entry for other formats.
      t.jsonb :text_pages, null: false, default: []
      t.integer :character_count, null: false, default: 0
      t.datetime :processed_at
    end
  end
end
