# One call to an AI model, for cost tracking and per-user daily limits.
class AiUsage < ApplicationRecord
  FEATURES = %w[posting_extraction match_report].freeze

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

  # Runs one AI call (the block returns [data, response]) and records its
  # model, tokens, latency and outcome, also when it fails.
  def self.track(user:, feature:)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    data, response = yield
    record!(user:, feature:, response:, started:, succeeded: true)
    [ data, response ]
  rescue Ai::Client::Error
    record!(user:, feature:, response: nil, started:, succeeded: false)
    raise
  end

  def self.record!(user:, feature:, response:, started:, succeeded:)
    create!(
      user:, feature:, succeeded:,
      model: response&.model.to_s.presence || Ai::Client.model,
      input_tokens: response&.usage&.input_tokens.to_i,
      output_tokens: response&.usage&.output_tokens.to_i,
      latency_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    )
  end
  private_class_method :record!
end
