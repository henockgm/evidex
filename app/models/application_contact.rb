# Someone the user deals with for an application: a recruiter, hiring manager, referrer.
class ApplicationContact < ApplicationRecord
  belongs_to :job_application, touch: true

  normalizes :name, :role, with: ->(value) { value.squish.presence }
  normalizes :email, with: ->(value) { value.strip.downcase.presence }
  normalizes :phone, with: ->(value) { value.squish.presence }
  normalizes :notes, with: ->(value) { value.strip.presence }

  validates :name, presence: true, length: { maximum: 100 }
  validates :role, length: { maximum: 100 }
  validates :email, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :phone, length: { maximum: 40 }, format: { with: /\A[0-9+()\-. ]+\z/, message: "can only contain digits, spaces and + ( ) - ." }, allow_nil: true
  validates :notes, length: { maximum: 2_000 }
end
