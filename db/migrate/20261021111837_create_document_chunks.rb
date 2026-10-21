class CreateDocumentChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :document_chunks do |t|
      t.references :document, null: false, foreign_key: { on_delete: :cascade }
      # Denormalised so every search can be scoped to the owner directly.
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.integer :page # 1-based, for PDFs
      t.string :section # nearest heading above the text
      t.text :content, null: false

      t.datetime :created_at, null: false
    end
    add_index :document_chunks, %i[document_id position], unique: true
  end
end
