class IdentitySerializer
  def initialize(identity)
    @identity = identity
  end

  def as_json(*)
    {
      id: @identity.id,
      provider: @identity.provider,
      label: @identity.label,
      email: @identity.email,
      created_at: @identity.created_at.iso8601
    }
  end
end
