class JobPostingSerializer
  def initialize(job_posting, include_description: false)
    @job_posting = job_posting
    @include_description = include_description
  end

  def as_json(*)
    json = {
      id: @job_posting.id,
      title: @job_posting.title,
      company: @job_posting.company,
      location: @job_posting.location,
      work_model: @job_posting.work_model,
      deadline: @job_posting.deadline&.iso8601,
      source_url: @job_posting.source_url,
      created_at: @job_posting.created_at.iso8601,
      updated_at: @job_posting.updated_at.iso8601
    }
    if @include_description
      json[:description] = @job_posting.description
      json[:requirements] = @job_posting.requirements.map { |requirement| RequirementSerializer.new(requirement) }
    end
    json
  end
end
