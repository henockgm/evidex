# A security event as admins see it: which account, what happened and from
# where. For admin actions it also names the admin who acted.
class AdminAuditEventSerializer
  DETAILS = (AuditEventSerializer::DETAILS + %w[sessions]).freeze

  def initialize(event, admins: {})
    @event = event
    @admins = admins
  end

  def as_json(*)
    {
      id: @event.id,
      action: @event.action,
      created_at: @event.created_at.iso8601,
      user: @event.user && { id: @event.user.id, email_address: @event.user.email_address },
      ip_address: @event.ip_address,
      device: @event.user_agent.present? ? DeviceName.for(@event.user_agent) : nil,
      details: @event.metadata.slice(*DETAILS),
      admin_email_address: @admins[@event.metadata["admin_id"]]
    }
  end
end
