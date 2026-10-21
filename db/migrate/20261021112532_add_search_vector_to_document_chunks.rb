class AddSearchVectorToDocumentChunks < ActiveRecord::Migration[8.1]
  def change
    # Full-text index for keyword search. The "simple" configuration doesn't
    # stem or drop stop words, so it treats Finnish and English alike.
    add_column :document_chunks, :search_vector, :virtual, type: :tsvector, stored: true,
      as: "to_tsvector('simple', coalesce(section, '') || ' ' || content)"
    add_index :document_chunks, :search_vector, using: :gin
  end
end
