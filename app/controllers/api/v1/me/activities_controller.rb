module Api
  module V1
    module Me
      # The user's own security activity, newest first: sign-ins, failures,
      # and changes to passwords, 2FA, devices and connected accounts.
      class ActivitiesController < BaseController
        PER_PAGE = 20

        def show
          page = [ params[:page].to_i, 1 ].max
          events = Current.user.audit_events
          total = events.count
          records = events.order(created_at: :desc, id: :desc).limit(PER_PAGE).offset((page - 1) * PER_PAGE)

          render json: {
            events: records.map { |event| AuditEventSerializer.new(event) },
            meta: { page:, per_page: PER_PAGE, total:, total_pages: (total.to_f / PER_PAGE).ceil }
          }
        end
      end
    end
  end
end
