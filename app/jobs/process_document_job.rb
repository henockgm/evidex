# Reads an uploaded document's text, splits it into chunks and embeds them for search.
class ProcessDocumentJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(document_id)
    document = Document.find(document_id)
    return unless document.status == "pending"

    document.update!(status: "processing", error: nil)
    pages = Library::TextExtractor.call(document.file.blob)
    chunks = Library::Chunker.call(pages, paginated: document.file.blob.content_type == "application/pdf")
    # The section is part of what gets embedded, so "Skills: Ruby" reads as a skill.
    embeddings = Library::Embedder.embed_passages(chunks.map { |chunk| [ chunk.section, chunk.content ].compact.uniq.join("\n") })

    Document.transaction do
      document.rebuild_chunks!(chunks, embeddings:, embedding_model: Library::Embedder.model_name)
      document.update!(status: "ready", text_pages: pages, character_count: pages.sum(&:length), processed_at: Time.current)
    end
  rescue Library::TextExtractor::Error => error
    document.update_columns(status: "failed", error: error.message.first(255), updated_at: Time.current)
  end
end
