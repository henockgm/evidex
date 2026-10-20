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
      status: @job_posting.job_application.status,
      created_at: @job_posting.created_at.iso8601,
      updated_at: @job_posting.updated_at.iso8601
    }
    if @include_description
      json[:description] = @job_posting.description
      json.merge!(
        employment_type: @job_posting.employment_type,
        seniority: @job_posting.seniority,
        salary: @job_posting.salary,
        keywords: @job_posting.keywords,
        extraction: {
          status: @job_posting.extraction_status,
          error: @job_posting.extraction_error,
          extracted_at: @job_posting.extracted_at&.iso8601
        }
      )
      json[:requirements] = @job_posting.requirements.map { |requirement| RequirementSerializer.new(requirement) }
      json[:application] = JobApplicationSerializer.new(@job_posting.job_application)
    end
    json
  end
end
