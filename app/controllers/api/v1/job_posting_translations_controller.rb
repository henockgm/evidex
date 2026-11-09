module Api
  module V1
    # Translates the requirements of a posting read before Evidex read ads
    # into English. Runs in the request: one short AI call.
    class JobPostingTranslationsController < BaseController
      def create
        posting = Current.user.job_postings.find(params[:job_posting_id])

        unless Current.user.verified?
          return render_problem(:forbidden, "Email not confirmed", detail: "Confirm your email address to use AI features.")
        end
        unless Ai::Client.configured?
          return render_problem(:service_unavailable, "AI not available", detail: "AI features aren't configured on this server.")
        end
        if posting.extraction_status == "pending"
          return render_problem(:conflict, "Being read", detail: "Wait until the posting has been read, then translate.")
        end
        if posting.requirements.where(source_text: nil).none?
          return render_problem(:unprocessable_content, "Nothing to translate", detail: "This posting has no requirements to translate.")
        end
        if AiUsage.limit_reached?(Current.user)
          return render_problem(:too_many_requests, "Daily AI limit reached",
            detail: "You can run #{AiUsage.daily_limit(Current.user)} AI extractions a day. Try again tomorrow.")
        end

        result = Ai::RequirementTranslator.new(posting).call
        posting.apply_translation!(language: result.language, translations: result.translations)
        render json: { job_posting: JobPostingSerializer.new(posting.reload, include_description: true) }
      rescue Ai::Client::Error => error
        render_problem(:bad_gateway, "Translation failed", detail: error.message)
      end
    end
  end
end
