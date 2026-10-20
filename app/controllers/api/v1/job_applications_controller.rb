module Api
  module V1
    class JobApplicationsController < BaseController
      def transition
        application = JobApplication.where(user: Current.user).find(params[:id])
        application.transition_to!(params.require(:to_status).to_s, note: params[:note].to_s)
        render json: { application: JobApplicationSerializer.new(application) }
      rescue JobApplication::InvalidTransition => error
        render_problem :unprocessable_content, "Status change not allowed", detail: error.message
      rescue ActiveRecord::RecordInvalid => error
        render_validation_errors(error.record)
      end
    end
  end
end
