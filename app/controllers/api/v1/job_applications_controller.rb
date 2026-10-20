module Api
  module V1
    class JobApplicationsController < BaseController
      def update
        if application.update(application_params)
          render json: { application: JobApplicationSerializer.new(application) }
        else
          render_validation_errors(application)
        end
      end

      def transition
        application.transition_to!(params.require(:to_status).to_s, note: params[:note].to_s)
        render json: { application: JobApplicationSerializer.new(application) }
      rescue JobApplication::InvalidTransition => error
        render_problem :unprocessable_content, "Status change not allowed", detail: error.message
      rescue ActiveRecord::RecordInvalid => error
        render_validation_errors(error.record)
      end

      private
        def application
          @application ||= JobApplication.where(user: Current.user).find(params[:id])
        end

        def application_params
          params.expect(job_application: [ :applied_on, :next_action, :next_action_on, :notes, links: [ [ :label, :url ] ] ])
        end
    end
  end
end
