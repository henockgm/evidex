class AuditEvent < ApplicationRecord
  ACTIONS = %w[
    registered registration_duplicate
    signed_in sign_in_failed account_locked signed_out
    session_revoked other_sessions_revoked
    email_verified password_reset_requested password_reset password_changed
    identity_linked identity_unlinked oauth_signed_in
  ].freeze

  belongs_to :user, optional: true

  validates :action, inclusion: { in: ACTIONS }

  def self.record(action, request:, user: nil, **metadata)
    create!(action: action.to_s, user:, metadata:,
      ip_address: request.remote_ip, user_agent: request.user_agent&.first(255))
  end
end
