# One line of a job posting: a required or preferred qualification, or a
# responsibility. Kept separate so each can be matched against the user's
# career documents later (M4). text is in English; for an ad in another
# language, source_text keeps the ad's own wording.
class Requirement < ApplicationRecord
  KINDS = %w[required preferred responsibility].freeze
  TEXT_MAX_LENGTH = 1_000

  belongs_to :job_posting, touch: true

  normalizes :text, with: ->(value) { value.squish }
  normalizes :source_text, with: ->(value) { value.squish.presence }

  validates :kind, inclusion: { in: KINDS }
  validates :text, presence: true, length: { maximum: TEXT_MAX_LENGTH }
  validates :source_text, length: { maximum: TEXT_MAX_LENGTH }

  before_create :append_to_kind

  scope :ordered, -> { order(:position, :id) }

  private
    def append_to_kind
      self.position = (job_posting.requirements.where(kind:).maximum(:position) || 0) + 1
    end
end
