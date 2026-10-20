class JobApplicationSerializer
  def initialize(application)
    @application = application
  end

  def as_json(*)
    {
      id: @application.id,
      status: @application.status,
      available_transitions: @application.available_transitions,
      applied_on: @application.applied_on&.iso8601,
      next_action: @application.next_action,
      next_action_on: @application.next_action_on&.iso8601,
      notes: @application.notes,
      links: @application.links,
      events: @application.events.map do |event|
        {
          id: event.id,
          from_status: event.from_status,
          to_status: event.to_status,
          note: event.note,
          created_at: event.created_at.iso8601
        }
      end
    }
  end
end
