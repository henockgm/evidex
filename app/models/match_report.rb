# How well the user's library covers one job posting's requirements.
# Each run creates a new version; older versions are kept.
class MatchReport < ApplicationRecord
  STATUSES = %w[pending running done failed].freeze

  belongs_to :job_posting
  belongs_to :user
  has_many :matches, -> { order(:position) }, class_name: "RequirementMatch", dependent: :delete_all, inverse_of: :match_report

  validates :status, inclusion: { in: STATUSES }

  scope :latest_first, -> { order(version: :desc) }

  def finished?
    status.in?(%w[done failed])
  end

  def counts
    tally = matches.map(&:verdict).tally
    RequirementMatch::VERDICTS.index_with { |verdict| tally.fetch(verdict, 0) }
  end
end
