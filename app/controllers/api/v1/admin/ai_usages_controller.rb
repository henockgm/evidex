module Api
  module V1
    module Admin
      # AI calls, tokens and estimated cost per account over a period (ADM-02).
      class AiUsagesController < BaseController
        PERIODS = [ 7, 30, 90 ].freeze

        def show
          days = PERIODS.include?(params[:days].to_i) ? params[:days].to_i : 30
          rows = AiUsage.where(created_at: days.days.ago..).group(:user_id, :model)
            .pluck(:user_id, :model, Arel.sql("COUNT(*)"), Arel.sql("COUNT(*) FILTER (WHERE NOT succeeded)"),
              Arel.sql("SUM(input_tokens)"), Arel.sql("SUM(output_tokens)"))
          emails = User.where(id: rows.map(&:first).uniq).pluck(:id, :email_address).to_h

          users = rows.group_by(&:first).map do |user_id, user_rows|
            summarize(user_rows).merge(user: { id: user_id, email_address: emails[user_id] })
          end

          render json: {
            days:,
            totals: summarize(rows),
            users: users.sort_by { |user| [ -user[:estimated_cost_usd], -user[:calls] ] }
          }
        end

        private
          # Rows of [user_id, model, calls, failed, input_tokens, output_tokens].
          # Models without a known price are left out of the cost and listed.
          def summarize(rows)
            costs = rows.map { |_, model, _, _, input, output| AiUsage.estimated_cost(model:, input_tokens: input, output_tokens: output) }
            {
              calls: rows.sum { |row| row[2] },
              failed_calls: rows.sum { |row| row[3] },
              input_tokens: rows.sum { |row| row[4] },
              output_tokens: rows.sum { |row| row[5] },
              estimated_cost_usd: costs.compact.sum.round(4),
              models: rows.map { |row| row[1] }.uniq.sort,
              unpriced_models: rows.zip(costs).filter_map { |row, cost| row[1] if cost.nil? }.uniq.sort
            }
          end
      end
    end
  end
end
