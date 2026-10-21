# Reads an uploaded document's text. Later steps add chunking and embeddings.
class ProcessDocumentJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(document_id)
    document = Document.find(document_id)
    return unless document.status == "pending"

    document.update!(status: "processing", error: nil)
    pages = Library::TextExtractor.call(document.file.blob)
    document.update!(status: "ready", text_pages: pages, character_count: pages.sum(&:length), processed_at: Time.current)
  rescue Library::TextExtractor::Error => error
    document.update_columns(status: "failed", error: error.message.first(255), updated_at: Time.current)
  end
end
