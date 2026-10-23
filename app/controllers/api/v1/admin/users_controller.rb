module Api
  module V1
    module Admin
      # Accounts on the instance, newest first, with account metadata only.
      class UsersController < BaseController
        PER_PAGE = 25

        def index
          page = [ params[:page].to_i, 1 ].max
          users = filtered_users
          total = users.count
          records = users.with_admin_stats.includes(:identities)
            .order(created_at: :desc, id: :desc).limit(PER_PAGE).offset((page - 1) * PER_PAGE)

          render json: {
            users: records.map { |user| AdminUserSerializer.new(user) },
            meta: { page:, per_page: PER_PAGE, total:, total_pages: (total.to_f / PER_PAGE).ceil }
          }
        end

        private
          def filtered_users
            query = params[:q].to_s.strip
            return User.all if query.blank?

            pattern = "%#{User.sanitize_sql_like(query)}%"
            User.where("users.email_address ILIKE :pattern OR users.name ILIKE :pattern", pattern:)
          end
      end
    end
  end
end
