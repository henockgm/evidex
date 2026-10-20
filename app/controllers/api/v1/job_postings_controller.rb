module Api
  module V1
    class JobPostingsController < BaseController
      def index
        postings = Current.user.job_postings.order(created_at: :desc)
        render json: { job_postings: postings.map { |posting| JobPostingSerializer.new(posting) } }
      end

      def show
        render json: { job_posting: JobPostingSerializer.new(job_posting, include_description: true) }
      end

      def create
        posting = Current.user.job_postings.new(job_posting_params)
        if posting.save
          render json: { job_posting: JobPostingSerializer.new(posting, include_description: true) }, status: :created
        else
          render_validation_errors(posting)
        end
      end

      private
        def job_posting
          @job_posting ||= Current.user.job_postings.find(params[:id])
        end

        def job_posting_params
          params.expect(job_posting: %i[title company location work_model deadline source_url description])
        end
    end
  end
end
