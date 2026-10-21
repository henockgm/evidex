class Interview < ApplicationRecord
  FORMATS = %w[video phone onsite other].freeze
  STATUSES = %w[scheduled completed cancelled].freeze

  belongs_to :job_application, touch: true

  normalizes :round, :location, with: ->(value) { value.squish.presence }
  normalizes :format, with: ->(value) { value.strip.presence }
  normalizes :notes, with: ->(value) { value.strip.presence }

  validates :scheduled_at, presence: true
  validates :round, length: { maximum: 100 }
  validates :location, length: { maximum: 500 }
  validates :format, inclusion: { in: FORMATS }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :notes, length: { maximum: 5_000 }

  scope :upcoming, -> { where(status: "scheduled", scheduled_at: Time.current..) }
end
