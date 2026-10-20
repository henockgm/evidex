module Api
  module V1
    module Me
      class SessionsController < BaseController
        def index
          sessions = Current.user.sessions.active.order(last_active_at: :desc)
          render json: { sessions: sessions.map { |session| SessionSerializer.new(session, current: session == Current.session) } }
        end

        def destroy
          session = Current.user.sessions.find(params[:id])
          AuditEvent.record(:session_revoked, user: Current.user, request:, session_id: session.id)

          if session == Current.session
            terminate_session
          else
            session.destroy!
          end
          head :no_content
        end

        def destroy_others
          count = Current.user.sessions.where.not(id: Current.session.id).delete_all
          AuditEvent.record(:other_sessions_revoked, user: Current.user, request:, count:)
          head :no_content
        end
      end
    end
  end
end
