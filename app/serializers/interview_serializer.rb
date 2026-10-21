class InterviewSerializer
  def initialize(interview)
    @interview = interview
  end

  def as_json(*)
    @interview.slice(:id, :round, :format, :location, :status, :notes).symbolize_keys
      .merge(scheduled_at: @interview.scheduled_at.iso8601)
  end
end
