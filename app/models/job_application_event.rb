class JobApplicationEvent < ApplicationRecord
  belongs_to :job_application

  normalizes :note, with: ->(note) { note.strip.presence }

  validates :to_status, inclusion: { in: JobApplication::STATUSES }
  validates :from_status, inclusion: { in: JobApplication::STATUSES }, allow_nil: true
  validates :note, length: { maximum: JobApplication::NOTE_MAX_LENGTH }
end
