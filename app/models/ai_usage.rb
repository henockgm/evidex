# One call to an AI model, for cost tracking and per-user daily limits.
class AiUsage < ApplicationRecord
  FEATURES = %w[posting_extraction].freeze

  belongs_to :user

  validates :feature, inclusion: { in: FEATURES }
  validates :model, presence: true

  scope :today, -> { where(created_at: Time.current.all_day) }

  def self.daily_limit
    Integer(ENV.fetch("EVIDEX_AI_DAILY_LIMIT", 20))
  end

  def self.limit_reached?(user)
    where(user:).today.count >= daily_limit
  end
end
