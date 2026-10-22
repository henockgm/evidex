class JobPosting < ApplicationRecord
  WORK_MODELS = %w[onsite hybrid remote].freeze
  EXTRACTION_STATUSES = %w[none pending done failed].freeze
  DESCRIPTION_MAX_LENGTH = 100_000

  belongs_to :user
  has_many :requirements, -> { ordered }, dependent: :delete_all, inverse_of: :job_posting
  has_one :job_application, dependent: :destroy
  has_many :match_reports, dependent: :destroy

  after_create { create_job_application!(user:) }

  normalizes :title, :company, with: ->(value) { value.squish }
  normalizes :location, :work_model, :employment_type, :seniority, :salary, with: ->(value) { value.squish.presence }
  normalizes :source_url, with: ->(value) { value.strip.presence }

  validates :title, :company, presence: true, length: { maximum: 200 }
  validates :location, :employment_type, :seniority, :salary, length: { maximum: 200 }
  validates :extraction_status, inclusion: { in: EXTRACTION_STATUSES }
  validates :work_model, inclusion: { in: WORK_MODELS }, allow_nil: true
  validates :description, presence: true, length: { maximum: DESCRIPTION_MAX_LENGTH }
  validates :source_url, length: { maximum: 2048 }, allow_nil: true
  validate :source_url_is_http

  # Fills in what the AI found without overwriting anything the user entered,
  # and adds requirements that aren't in the list yet.
  def apply_extraction!(result)
    transaction do
      result.fields.each do |field, value|
        self[field] = value if self[field].blank?
      end
      self.keywords = (keywords + result.keywords).uniq { |keyword| keyword.downcase }

      existing = requirements.map { |requirement| [ requirement.kind, requirement.text.downcase ] }.to_set
      result.requirements.each do |kind, texts|
        texts.each do |text|
          next if existing.include?([ kind, text.downcase ])

          requirements.create!(kind:, text:)
          existing << [ kind, text.downcase ]
        end
      end

      update!(extraction_status: "done", extraction_error: nil, extracted_at: Time.current)
    end
  end

  private
    def source_url_is_http
      return if source_url.nil?

      uri = URI.parse(source_url)
      errors.add(:source_url, "must be an http or https link") unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(:source_url, "must be an http or https link")
    end
end
