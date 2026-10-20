# Where the user is with a job posting. Moves through a fixed set of statuses;
# every change is recorded as a JobApplicationEvent to build the timeline.
class JobApplication < ApplicationRecord
  class InvalidTransition < StandardError; end

  # Allowed next statuses. "withdrawn" covers dropping out and declining an offer.
  TRANSITIONS = {
    "saved" => %w[preparing applied withdrawn],
    "preparing" => %w[saved applied withdrawn],
    "applied" => %w[interviewing offer rejected withdrawn],
    "interviewing" => %w[offer rejected withdrawn],
    "offer" => %w[withdrawn],
    "rejected" => [],
    "withdrawn" => []
  }.freeze
  STATUSES = TRANSITIONS.keys.freeze
  NOTE_MAX_LENGTH = 2_000

  belongs_to :user
  belongs_to :job_posting
  has_many :events, -> { order(:created_at, :id) }, class_name: "JobApplicationEvent", dependent: :delete_all,
    inverse_of: :job_application

  validates :status, inclusion: { in: STATUSES }
  validates :job_posting_id, uniqueness: true

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
      update!(status: new_status)
    end
  end
end
