class DocumentChunk < ApplicationRecord
  belongs_to :document
  belongs_to :user

  has_neighbors :embedding

  scope :ordered, -> { order(:position) }
end
