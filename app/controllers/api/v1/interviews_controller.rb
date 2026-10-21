module Api
  module V1
    class InterviewsController < BaseController
      # Adding an interview moves the application to "interviewing" when that's
      # a valid next step (e.g. from "applied" or "no_response").
      def create
        application = JobApplication.where(user: Current.user).find(params[:job_application_id])
        interview = application.interviews.new(interview_params)

        Interview.transaction do
          interview.save!
          if application.available_transitions.include?("interviewing")
            application.transition_to!("interviewing", note: "Interview scheduled#{": #{interview.round}" if interview.round}")
          end
        end
        render json: { interview: InterviewSerializer.new(interview) }, status: :created
      rescue ActiveRecord::RecordInvalid
        render_validation_errors(interview)
      end

      def update
        if interview.update(interview_params)
          render json: { interview: InterviewSerializer.new(interview) }
        else
          render_validation_errors(interview)
        end
      end

      def destroy
        interview.destroy!
        head :no_content
      end

      private
        def interview
          @interview ||= Interview.joins(:job_application)
            .where(job_applications: { user_id: Current.user.id }).find(params[:id])
        end

        def interview_params
          params.expect(interview: %i[round scheduled_at format location status notes])
        end
    end
  end
end
