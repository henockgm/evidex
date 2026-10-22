# A passage cited as evidence, stored as a snapshot so it survives the
# document being re-read or deleted.
class MatchCitation < ApplicationRecord
  belongs_to :requirement_match
  belongs_to :document_chunk, optional: true
  belongs_to :document, optional: true
end
