# The verdict for one requirement in a match report.
class RequirementMatch < ApplicationRecord
  VERDICTS = %w[evidenced transferable gap].freeze

  belongs_to :match_report
  belongs_to :requirement, optional: true
  has_many :citations, class_name: "MatchCitation", dependent: :delete_all, inverse_of: :requirement_match

  validates :verdict, inclusion: { in: VERDICTS }
end
