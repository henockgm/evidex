module Api
  module V1
    class MatchReportsController < BaseController
      # Starts a new report version; GenerateMatchReportJob does the work.
      def create
        posting = Current.user.job_postings.find(params[:job_posting_id])
        if (status, title, detail = blocker(posting))
          return render_problem(status, title, detail:)
        end

        report = posting.match_reports.create!(user: Current.user, version: (posting.match_reports.maximum(:version) || 0) + 1)
        GenerateMatchReportJob.perform_later(report.id)
        render json: { match_report: MatchReportSerializer.new(report) }, status: :accepted
      end

      # All versions for a posting, newest first, without the per-requirement details.
      def index
        posting = Current.user.job_postings.find(params[:job_posting_id])
        reports = posting.match_reports.latest_first.includes(:matches)
        render json: {
          match_reports: reports.map do |report|
            report.slice(:id, :version, :status, :model).symbolize_keys.merge(
              counts: report.counts, created_at: report.created_at.iso8601, completed_at: report.completed_at&.iso8601
            )
          end
        }
      end

      # The latest report for a posting, whatever its status.
      def latest
        posting = Current.user.job_postings.find(params[:id])
        report = posting.match_reports.latest_first.includes(matches: :citations).first
        return render_problem(:not_found, "No match report yet") unless report

        render json: { match_report: MatchReportSerializer.new(report) }
      end

      def show
        report = MatchReport.where(user: Current.user).includes(matches: :citations).find(params[:id])
        render json: { match_report: MatchReportSerializer.new(report) }
      end

      private
        def blocker(posting)
          if !Current.user.verified?
            [ :forbidden, "Email not confirmed", "Confirm your email address to use AI features." ]
          elsif !Ai::Client.configured?
            [ :service_unavailable, "AI not available", "AI features aren't configured on this server." ]
          elsif posting.requirements.none?
            [ :unprocessable_content, "No requirements", "Add requirements to the posting first, or read it with AI." ]
          elsif Current.user.documents.where(status: "ready").none?
            [ :unprocessable_content, "Library is empty", "Upload your CV to the career library first." ]
          elsif posting.match_reports.where(status: %w[pending running]).exists?
            [ :conflict, "Already running", "A match report for this posting is being prepared." ]
          elsif AiUsage.limit_reached?(Current.user)
            [ :too_many_requests, "Daily AI limit reached", "You can run #{AiUsage.daily_limit(Current.user)} AI tasks a day. Try again tomorrow." ]
          end
        end
    end
  end
end
