# The verdict for one requirement in a match report.
class RequirementMatch < ApplicationRecord
  VERDICTS = %w[evidenced transferable gap].freeze

  belongs_to :match_report
  belongs_to :requirement, optional: true
  has_many :citations, class_name: "MatchCitation", dependent: :delete_all, inverse_of: :requirement_match

  normalizes :user_verdict, with: ->(value) { value.strip.presence }
  normalizes :user_note, with: ->(value) { value.strip.presence }

  validates :verdict, inclusion: { in: VERDICTS }
  validates :user_verdict, inclusion: { in: VERDICTS }, allow_nil: true
  validates :user_note, length: { maximum: 2_000 }

  # The user's verdict when they've set one, otherwise the AI's.
  def effective_verdict
    user_verdict || verdict
  end
end
