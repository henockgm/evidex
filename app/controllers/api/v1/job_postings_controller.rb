module Api
  module V1
    class JobPostingsController < BaseController
      def index
        result = JobPostingsQuery.new(Current.user.job_postings, params.permit(:status, :q, :deadline, :sort, :page, :per_page)).call
        render json: {
          job_postings: result.records.map { |posting| JobPostingSerializer.new(posting) },
          meta: {
            page: result.page,
            per_page: result.per_page,
            total: result.total,
            total_pages: (result.total.to_f / result.per_page).ceil
          }
        }
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

      def update
        if job_posting.update(job_posting_params)
          render json: { job_posting: JobPostingSerializer.new(job_posting, include_description: true) }
        else
          render_validation_errors(job_posting)
        end
      end

      def destroy
        job_posting.destroy!
        head :no_content
      end

      private
        def job_posting
          @job_posting ||= Current.user.job_postings.find(params[:id])
        end

        def job_posting_params
          params.expect(job_posting: %i[title company location work_model employment_type seniority salary deadline source_url description])
        end
    end
  end
end
