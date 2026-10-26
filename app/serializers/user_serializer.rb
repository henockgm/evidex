class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      id: @user.id,
      email_address: @user.email_address,
      name: @user.name,
      email_verified: @user.verified?,
      has_password: @user.password?,
      ai_configured: Ai::Client.configured?,
      two_factor_enabled: @user.two_factor_enabled?,
      recovery_codes_remaining: @user.two_factor_enabled? ? @user.recovery_codes.unused.count : 0,
      identities: @user.identities.map { |identity| IdentitySerializer.new(identity).as_json },
      admin: @user.admin?,
      demo: @user.demo?,
      created_at: @user.created_at.iso8601
    }
  end
end
