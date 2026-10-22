module Api
  module V1
    # The user's own verdict and note on one requirement of a match report.
    class RequirementMatchesController < BaseController
      def update
        match = RequirementMatch.joins(:match_report).where(match_reports: { user_id: Current.user.id }).find(params[:id])

        if match.update(params.expect(requirement_match: %i[user_verdict user_note]))
          render json: { match_report: MatchReportSerializer.new(match.match_report.reload) }
        else
          render_validation_errors(match)
        end
      end
    end
  end
end
