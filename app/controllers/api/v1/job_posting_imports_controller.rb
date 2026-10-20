module Api
  module V1
    # Fetches a job ad from a link and returns a draft posting to review.
    # Nothing is saved: the user checks the draft and saves it with POST /job_postings.
    class JobPostingImportsController < BaseController
      limit_requests to: 10, within: 1.minute, by: -> { Current.user&.id || request.remote_ip }

      def create
        page = SafeFetcher.new.get(params.require(:url))
        draft = PostingPageParser.parse(page.body, url: page.url)

        render json: {
          draft: {
            title: draft.title,
            company: draft.company,
            location: draft.location,
            work_model: draft.work_model,
            deadline: draft.deadline&.iso8601,
            source_url: page.url,
            description: draft.description
          },
          structured_data: draft.structured
        }
      rescue SafeFetcher::Error => error
        render_problem :unprocessable_content, "Couldn't import that link", detail: error.message
      end
    end
  end
end
