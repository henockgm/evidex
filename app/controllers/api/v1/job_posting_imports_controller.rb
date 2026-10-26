module Api
  module V1
    # Fetches a job ad from a link and returns a draft posting to review.
    # Nothing is saved: the user checks the draft and saves it with POST /job_postings.
    # possible_duplicates lists the user's postings for the same ad (see AdLink).
    class JobPostingImportsController < BaseController
      limit_requests to: 10, within: 1.minute, by: -> { Current.user&.id || request.remote_ip }

      def create
        url = params.require(:url)
        page = SafeFetcher.new.get(url)
        draft = PostingPageParser.parse(page.body, url: page.url)
        duplicates = Current.user.job_postings.linking_to(url, page.url).includes(:job_application).order(:created_at)

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
          structured_data: draft.structured,
          possible_duplicates: duplicates.map { |posting| JobPostingSerializer.new(posting) }
        }
      rescue SafeFetcher::Error => error
        render_problem :unprocessable_content, "Couldn't import that link", detail: error.message
      end
    end
  end
end
