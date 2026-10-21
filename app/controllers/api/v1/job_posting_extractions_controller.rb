module Api
  module V1
    # Starts AI extraction of a posting's fields and requirements. The work runs
    # in ExtractPostingJob; poll the posting until extraction.status leaves "pending".
    class JobPostingExtractionsController < BaseController
      def create
        posting = Current.user.job_postings.find(params[:job_posting_id])

        unless Current.user.verified?
          return render_problem(:forbidden, "Email not confirmed", detail: "Confirm your email address to use AI features.")
        end
        unless Ai::Client.configured?
          return render_problem(:service_unavailable, "AI not available", detail: "AI features aren't configured on this server.")
        end
        if posting.extraction_status == "pending"
          return render_problem(:conflict, "Already running", detail: "This posting is already being read.")
        end
        if AiUsage.limit_reached?(Current.user)
          return render_problem(:too_many_requests, "Daily AI limit reached",
            detail: "You can run #{AiUsage.daily_limit} AI extractions a day. Try again tomorrow.")
        end

        posting.update!(extraction_status: "pending", extraction_error: nil)
        ExtractPostingJob.perform_later(posting.id)
        render json: { job_posting: JobPostingSerializer.new(posting, include_description: true) }, status: :accepted
      end
    end
  end
end
