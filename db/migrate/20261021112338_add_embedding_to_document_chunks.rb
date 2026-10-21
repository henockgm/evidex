class AddEmbeddingToDocumentChunks < ActiveRecord::Migration[8.1]
  def change
    add_column :document_chunks, :embedding, :vector, limit: 384
    # Which model produced the vector, so chunks can be re-embedded after a model change.
    add_column :document_chunks, :embedding_model, :string
    add_index :document_chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
