class DocumentSerializer
  def initialize(document)
    @document = document
  end

  def as_json(*)
    blob = @document.file.blob
    {
      id: @document.id,
      title: @document.title,
      kind: @document.kind,
      primary: @document.primary,
      status: @document.status,
      error: @document.error,
      filename: blob&.filename.to_s,
      content_type: blob&.content_type,
      byte_size: blob&.byte_size,
      page_count: @document.text_pages.size,
      character_count: @document.character_count,
      chunk_count: @document.chunks.size,
      processed_at: @document.processed_at&.iso8601,
      created_at: @document.created_at.iso8601,
      updated_at: @document.updated_at.iso8601
    }
  end
end
