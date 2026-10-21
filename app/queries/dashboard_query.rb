# Everything the dashboard shows, for one user.
class DashboardQuery
  OPEN_STATUSES = %w[saved preparing].freeze # not applied yet, so the deadline still matters
  DEADLINE_WINDOW = 14.days
  NEXT_ACTION_WINDOW = 7.days
  INTERVIEW_WINDOW = 14.days

  # Days in "applied" without any status change before an application is listed as "No reply yet".
  def self.no_reply_days
    Integer(ENV.fetch("EVIDEX_NO_REPLY_DAYS", 21))
  end
  LIST_LIMIT = 5

  def initialize(user, today: Date.current)
    @user = user
    @today = today
  end

  def call
    {
      status_counts: status_counts,
      total: postings.count,
      upcoming_interviews: upcoming_interviews,
      upcoming_deadlines: upcoming_deadlines,
      next_actions: next_actions,
      no_reply: no_reply,
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

    def upcoming_interviews
      Interview.upcoming.joins(:job_application).where(job_applications: { user_id: @user.id })
        .where(scheduled_at: ..(@today + INTERVIEW_WINDOW).end_of_day)
        .includes(job_application: :job_posting)
        .order(:scheduled_at, :id).limit(LIST_LIMIT)
        .map do |interview|
          posting_brief(interview.job_application.job_posting).merge(
            interview_id: interview.id, round: interview.round, format: interview.format,
            scheduled_at: interview.scheduled_at.iso8601
          )
        end
    end

    # Waiting in "applied" since the last status change, longest first.
    def no_reply
      cutoff = (@today - self.class.no_reply_days).end_of_day
      applications.where(status: "applied").joins(:events)
        .select("job_applications.*, MAX(job_application_events.created_at) AS waiting_since")
        .group("job_applications.id")
        .having("MAX(job_application_events.created_at) <= ?", cutoff)
        .order("waiting_since ASC, job_applications.id ASC").limit(LIST_LIMIT)
        .includes(:job_posting)
        .map do |application|
          waiting_since = application.waiting_since.to_date
          posting_brief(application.job_posting).merge(
            job_application_id: application.id,
            applied_on: (application.applied_on || waiting_since).iso8601,
            days_waiting: (@today - waiting_since).to_i
          )
        end
    end

    # Overdue ones included, so nothing slips.
    def next_actions
      applications.includes(:job_posting)
        .where(next_action_on: ..(@today + NEXT_ACTION_WINDOW))
        .where.not(status: JobApplication::CLOSED_STATUSES)
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
