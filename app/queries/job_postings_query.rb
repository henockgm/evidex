# Filters, searches, sorts and paginates a user's job postings for the list view.
#
#   JobPostingsQuery.new(user.job_postings, status: "applied,interviewing", q: "rails",
#                        deadline: "upcoming", sort: "deadline", page: 2).call
class JobPostingsQuery
  Result = Data.define(:records, :page, :per_page, :total)

  SORTS = {
    "newest" => { created_at: :desc },
    "oldest" => { created_at: :asc },
    "deadline" => Arel.sql("job_postings.deadline ASC NULLS LAST, job_postings.created_at DESC"),
    "company" => Arel.sql("LOWER(job_postings.company) ASC, job_postings.created_at DESC"),
    "next_action" => Arel.sql("job_applications.next_action_on ASC NULLS LAST, job_postings.created_at DESC"),
    "updated" => { updated_at: :desc }
  }.freeze
  DEADLINES = %w[upcoming overdue none].freeze
  UPCOMING_DAYS = 7
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100

  def initialize(scope, params = {})
    @scope = scope
    @params = params.to_h.symbolize_keys
  end

  def call
    relation = filtered
    total = relation.count
    records = relation.includes(:job_application).order(sort_order).limit(per_page).offset((page - 1) * per_page).to_a

    Result.new(records:, page:, per_page:, total:)
  end

  private
    def filtered
      relation = @scope.joins(:job_application)
      relation = relation.where(job_applications: { status: statuses }) if statuses.any?
      relation = search(relation) if @params[:q].present?
      relation = by_deadline(relation) if DEADLINES.include?(@params[:deadline])
      relation
    end

    # Comma-separated list; unknown statuses are ignored.
    def statuses
      @statuses ||= @params[:status].to_s.split(",").map(&:strip) & JobApplication::STATUSES
    end

    def search(relation)
      terms = @params[:q].to_s.squish.first(100).split(" ")
      terms.reduce(relation) do |result, term|
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
        result.where("job_postings.title ILIKE :p OR job_postings.company ILIKE :p OR job_postings.location ILIKE :p", p: pattern)
      end
    end

    def by_deadline(relation)
      today = Date.current
      case @params[:deadline]
      when "upcoming" then relation.where(deadline: today..(today + UPCOMING_DAYS))
      when "overdue" then relation.where(deadline: ...today)
      when "none" then relation.where(deadline: nil)
      end
    end

    def sort_order
      SORTS.fetch(@params[:sort].to_s, SORTS["newest"])
    end

    def page
      [ @params[:page].to_i, 1 ].max
    end

    def per_page
      value = @params[:per_page].to_i
      value.positive? ? [ value, MAX_PER_PAGE ].min : DEFAULT_PER_PAGE
    end
end
