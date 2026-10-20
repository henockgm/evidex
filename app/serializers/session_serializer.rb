class SessionSerializer
  def initialize(session, current:)
    @session = session
    @current = current
  end

  def as_json(*)
    {
      id: @session.id,
      current: @current,
      ip_address: @session.ip_address,
      user_agent: @session.user_agent,
      created_at: @session.created_at.iso8601,
      last_active_at: @session.last_active_at.iso8601
    }
  end
end
