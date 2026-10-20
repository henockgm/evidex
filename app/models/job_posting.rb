class JobPosting < ApplicationRecord
  WORK_MODELS = %w[onsite hybrid remote].freeze
  DESCRIPTION_MAX_LENGTH = 100_000

  belongs_to :user
  has_many :requirements, -> { ordered }, dependent: :delete_all, inverse_of: :job_posting

  normalizes :title, :company, with: ->(value) { value.squish }
  normalizes :location, :work_model, with: ->(value) { value.squish.presence }
  normalizes :source_url, with: ->(value) { value.strip.presence }

  validates :title, :company, presence: true, length: { maximum: 200 }
  validates :location, length: { maximum: 200 }
  validates :work_model, inclusion: { in: WORK_MODELS }, allow_nil: true
  validates :description, presence: true, length: { maximum: DESCRIPTION_MAX_LENGTH }
  validates :source_url, length: { maximum: 2048 }, allow_nil: true
  validate :source_url_is_http

  private
    def source_url_is_http
      return if source_url.nil?

      uri = URI.parse(source_url)
      errors.add(:source_url, "must be an http or https link") unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(:source_url, "must be an http or https link")
    end
end
