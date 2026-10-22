# One entry of the user's security activity. Only metadata that helps the user
# recognise the event is shown; internal ids stay private.
class AuditEventSerializer
  DETAILS = %w[provider method second_factor until].freeze

  def initialize(event)
    @event = event
  end

  def as_json(*)
    {
      id: @event.id,
      action: @event.action,
      created_at: @event.created_at.iso8601,
      ip_address: @event.ip_address,
      device: @event.user_agent.present? ? DeviceName.for(@event.user_agent) : nil,
      details: @event.metadata.slice(*DETAILS)
    }
  end
end
