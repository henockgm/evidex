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
      identities: @user.identities.map { |identity| IdentitySerializer.new(identity).as_json },
      created_at: @user.created_at.iso8601
    }
  end
end
