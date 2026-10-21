module Api
  module V1
    class RequirementsController < BaseController
      def create
        posting = Current.user.job_postings.find(params[:job_posting_id])
        requirement = posting.requirements.new(requirement_params)

        if requirement.save
          render json: { requirement: RequirementSerializer.new(requirement) }, status: :created
        else
          render_validation_errors(requirement)
        end
      end

      def update
        if requirement.update(requirement_params.slice(:text))
          render json: { requirement: RequirementSerializer.new(requirement) }
        else
          render_validation_errors(requirement)
        end
      end

      def destroy
        requirement.destroy!
        head :no_content
      end

      private
        def requirement
          @requirement ||= Requirement.joins(:job_posting).where(job_postings: { user_id: Current.user.id }).find(params[:id])
        end

        def requirement_params
          params.expect(requirement: %i[kind text])
        end
    end
  end
end
