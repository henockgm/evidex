module Api
  module V1
    module Admin
      # Security events across all accounts, newest first (ADM-02).
      class AuditEventsController < BaseController
        PER_PAGE = 50

        def index
          page = [ params[:page].to_i, 1 ].max
          events = AuditEvent.all
          events = events.where(user_id: params[:user_id]) if params[:user_id].present?
          events = events.where(action: params[:event_action]) if params[:event_action].present?
          total = events.count
          records = events.includes(:user).order(created_at: :desc, id: :desc).limit(PER_PAGE).offset((page - 1) * PER_PAGE).to_a
          admin_ids = records.filter_map { |event| event.metadata["admin_id"] }.uniq
          admins = User.where(id: admin_ids).pluck(:id, :email_address).to_h

          render json: {
            events: records.map { |event| AdminAuditEventSerializer.new(event, admins:) },
            meta: { page:, per_page: PER_PAGE, total:, total_pages: (total.to_f / PER_PAGE).ceil }
          }
        end
      end
    end
  end
end
