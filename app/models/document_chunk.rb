class DocumentChunk < ApplicationRecord
  belongs_to :document
  belongs_to :user

  scope :ordered, -> { order(:position) }
end
