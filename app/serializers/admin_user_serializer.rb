# What admins see about an account: who it is, how it signs in and how it's
# used. Never anything the user has written or uploaded (ADM-03).
class AdminUserSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      id: @user.id,
      email_address: @user.email_address,
      name: @user.name,
      admin: @user.admin?,
      email_verified: @user.verified?,
      has_password: @user.password?,
      two_factor_enabled: @user.two_factor_enabled?,
      providers: @user.identities.map(&:provider).sort,
      locked_until: @user.temporarily_locked? ? @user.locked_until.iso8601 : nil,
      suspended_at: @user.suspended_at&.iso8601,
      active_sessions: @user.active_sessions_count.to_i,
      last_active_at: @user.last_active_at&.iso8601,
      ai_calls_last_30_days: @user.ai_calls_last_30_days.to_i,
      created_at: @user.created_at.iso8601
    }
  end
end
