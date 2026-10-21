# Where the user is with a job posting. Moves through a fixed set of statuses;
# every change is recorded as a JobApplicationEvent to build the timeline.
class JobApplication < ApplicationRecord
  class InvalidTransition < StandardError; end

  # Allowed next statuses. "withdrawn" covers dropping out and declining an offer;
  # "no_response" closes an application the employer never answered, but a late
  # reply can still move it on.
  TRANSITIONS = {
    "saved" => %w[preparing applied withdrawn],
    "preparing" => %w[saved applied withdrawn],
    "applied" => %w[interviewing offer rejected no_response withdrawn],
    "interviewing" => %w[offer rejected no_response withdrawn],
    "offer" => %w[accepted withdrawn],
    "accepted" => [],
    "rejected" => [],
    "no_response" => %w[interviewing offer rejected],
    "withdrawn" => []
  }.freeze
  STATUSES = TRANSITIONS.keys.freeze
  # Finished, one way or another: no deadlines or follow-ups needed.
  CLOSED_STATUSES = %w[accepted rejected no_response withdrawn].freeze
  NOTE_MAX_LENGTH = 2_000
  NOTES_MAX_LENGTH = 20_000
  MAX_LINKS = 20

  belongs_to :user
  belongs_to :job_posting
  has_many :events, -> { order(:created_at, :id) }, class_name: "JobApplicationEvent", dependent: :delete_all,
    inverse_of: :job_application
  has_many :contacts, -> { order(:created_at, :id) }, class_name: "ApplicationContact", dependent: :delete_all,
    inverse_of: :job_application

  normalizes :next_action, with: ->(value) { value.squish.presence }
  normalizes :notes, with: ->(value) { value.strip.presence }
  normalizes :links, with: ->(links) { normalize_links(links) }

  validates :status, inclusion: { in: STATUSES }
  validates :job_posting_id, uniqueness: true
  validates :next_action, length: { maximum: 200 }
  validates :notes, length: { maximum: NOTES_MAX_LENGTH }
  validate :links_are_valid

  # Keeps only { "label", "url" } pairs, trimmed; drops rows with neither.
  def self.normalize_links(links)
    Array(links).filter_map do |link|
      link = link.to_h.stringify_keys
      label = link["label"].to_s.squish
      url = link["url"].to_s.strip
      { "label" => label.presence, "url" => url } if label.present? || url.present?
    end
  end

  after_create { events.create!(from_status: nil, to_status: status) }

  def available_transitions
    TRANSITIONS.fetch(status)
  end

  def transition_to!(new_status, note: nil)
    with_lock do
      unless available_transitions.include?(new_status)
        raise InvalidTransition, "Can't move from #{status} to #{new_status}"
      end

      events.create!(from_status: status, to_status: new_status, note: note.presence)
      self.applied_on ||= Date.current if new_status == "applied"
      update!(status: new_status)
    end
  end

  private
    def links_are_valid
      errors.add(:links, "can have at most #{MAX_LINKS} entries") if links.size > MAX_LINKS
      links.each do |link|
        label, url = link.values_at("label", "url")
        errors.add(:links, "need a link for \"#{label}\"") if url.blank?
        next if url.blank?

        uri = URI.parse(url)
        valid = uri.is_a?(URI::HTTP) && uri.host.present? && url.length <= 2048
        errors.add(:links, "must be http or https links (#{url.first(60)})") unless valid
        errors.add(:links, "labels can be at most 100 characters") if label.to_s.length > 100
      rescue URI::InvalidURIError
        errors.add(:links, "must be http or https links (#{url.first(60)})")
      end
    end
end
