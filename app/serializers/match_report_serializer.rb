class MatchReportSerializer
  def initialize(report)
    @report = report
  end

  def as_json(*)
    {
      id: @report.id,
      job_posting_id: @report.job_posting_id,
      version: @report.version,
      status: @report.status,
      error: @report.error,
      model: @report.model,
      counts: @report.counts,
      strengths: @report.strengths,
      gaps: @report.gaps,
      created_at: @report.created_at.iso8601,
      completed_at: @report.completed_at&.iso8601,
      matches: @report.matches.map { |match| match_json(match) }
    }
  end

  private
    def match_json(match)
      {
        id: match.id,
        requirement_id: match.requirement_id,
        requirement_kind: match.requirement_kind,
        requirement_text: match.requirement_text,
        verdict: match.verdict,
        reasoning: match.reasoning,
        citations: match.citations.map do |citation|
          citation.slice(:id, :document_id, :document_title, :page, :section, :excerpt).symbolize_keys
        end
      }
    end
end
