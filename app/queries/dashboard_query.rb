# Everything the dashboard shows, for one user.
class DashboardQuery
  OPEN_STATUSES = %w[saved preparing].freeze # not applied yet, so the deadline still matters
  DEADLINE_WINDOW = 14.days
  NEXT_ACTION_WINDOW = 7.days
  LIST_LIMIT = 5

  def initialize(user, today: Date.current)
    @user = user
    @today = today
  end

  def call
    {
      status_counts: status_counts,
      total: postings.count,
      upcoming_deadlines: upcoming_deadlines,
      next_actions: next_actions,
      recent_activity: recent_activity
    }
  end

  private
    def postings
      @user.job_postings
    end

    def applications
      JobApplication.where(user: @user)
    end

    def status_counts
      counts = applications.group(:status).count
      JobApplication::STATUSES.index_with { |status| counts.fetch(status, 0) }
    end

    def upcoming_deadlines
      postings.joins(:job_application)
        .where(job_applications: { status: OPEN_STATUSES }, deadline: @today..(@today + DEADLINE_WINDOW))
        .order(:deadline, :id).limit(LIST_LIMIT)
        .map { |posting| posting_brief(posting).merge(deadline: posting.deadline.iso8601) }
    end

    # Overdue ones included, so nothing slips.
    def next_actions
      applications.includes(:job_posting)
        .where(next_action_on: ..(@today + NEXT_ACTION_WINDOW))
        .where.not(status: %w[rejected withdrawn])
        .order(:next_action_on, :id).limit(LIST_LIMIT)
        .map do |application|
          posting_brief(application.job_posting).merge(
            next_action: application.next_action,
            next_action_on: application.next_action_on.iso8601,
            overdue: application.next_action_on < @today
          )
        end
    end

    def recent_activity
      JobApplicationEvent.joins(:job_application).where(job_applications: { user_id: @user.id })
        .includes(job_application: :job_posting)
        .order(created_at: :desc, id: :desc).limit(LIST_LIMIT)
        .map do |event|
          posting_brief(event.job_application.job_posting).merge(
            from_status: event.from_status, to_status: event.to_status, created_at: event.created_at.iso8601
          )
        end
    end

    def posting_brief(posting)
      { job_posting_id: posting.id, title: posting.title, company: posting.company }
    end
end
