# A file in the user's career library: a CV, project write-up, certificate or
# reference. The text is extracted and indexed in later steps (M3).
class Document < ApplicationRecord
  KINDS = %w[cv project certificate reference other].freeze
  STATUSES = %w[pending processing ready failed].freeze
  MAX_BYTES = 10.megabytes
  # Checked against the type Active Storage detects from the file's content,
  # not just the extension the browser reports.
  CONTENT_TYPES = {
    "application/pdf" => "PDF",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "Word (.docx)",
    "text/markdown" => "Markdown",
    "text/plain" => "Plain text"
  }.freeze

  belongs_to :user
  has_one_attached :file
  has_many :chunks, -> { ordered }, class_name: "DocumentChunk", dependent: :delete_all, inverse_of: :document

  normalizes :title, with: ->(value) { value.squish }

  validates :title, presence: true, length: { maximum: 200 }
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validate :file_is_acceptable
  validate :only_cvs_are_primary

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  after_create_commit -> { ProcessDocumentJob.perform_later(id) }

  def text
    text_pages.join("\n\n")
  end

  # Replaces the document's chunks with freshly split and embedded ones.
  def rebuild_chunks!(pieces, embeddings:, embedding_model:)
    now = Time.current
    transaction do
      chunks.delete_all
      rows = pieces.each_with_index.map do |piece, index|
        { document_id: id, user_id:, position: index, page: piece.page, section: piece.section&.first(200),
          content: piece.content, embedding: embeddings[index], embedding_model:, created_at: now }
      end
      DocumentChunk.insert_all!(rows) if rows.any?
    end
  end

  # Starts reading the file again after a failure.
  def retry_processing!
    update!(status: "pending", error: nil)
    ProcessDocumentJob.perform_later(id)
  end

  # Makes this the user's main CV; the previous one stops being primary.
  def make_primary!
    transaction do
      user.documents.where(primary: true).where.not(id:).update_all(primary: false, updated_at: Time.current)
      update!(primary: true)
    end
  end

  private
    def file_is_acceptable
      unless file.attached?
        errors.add(:file, "is required")
        return
      end

      blob = file.blob
      errors.add(:file, "must be a PDF, Word (.docx), Markdown or plain text file") unless CONTENT_TYPES.key?(blob.content_type)
      errors.add(:file, "must be #{MAX_BYTES / 1.megabyte} MB or smaller") if blob.byte_size > MAX_BYTES
      errors.add(:file, "is empty") if blob.byte_size.zero?
    end

    def only_cvs_are_primary
      errors.add(:primary, "can only be set on a CV") if primary? && kind != "cv"
    end
end
