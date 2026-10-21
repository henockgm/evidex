module Api
  module V1
    class ApplicationContactsController < BaseController
      def create
        application = JobApplication.where(user: Current.user).find(params[:job_application_id])
        contact = application.contacts.new(contact_params)

        if contact.save
          render json: { contact: ApplicationContactSerializer.new(contact) }, status: :created
        else
          render_validation_errors(contact)
        end
      end

      def update
        if contact.update(contact_params)
          render json: { contact: ApplicationContactSerializer.new(contact) }
        else
          render_validation_errors(contact)
        end
      end

      def destroy
        contact.destroy!
        head :no_content
      end

      private
        def contact
          @contact ||= ApplicationContact.joins(:job_application)
            .where(job_applications: { user_id: Current.user.id }).find(params[:id])
        end

        def contact_params
          params.expect(contact: %i[name role email phone notes])
        end
    end
  end
end
