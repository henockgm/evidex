require "rails_helper"

RSpec.describe DashboardQuery do
  let(:user) { create(:user) }
  let(:today) { Date.new(2026, 10, 20) }

  around { |example| travel_to(today) { example.run } }

  def posting(status: "saved", **attributes)
    create(:job_posting, user:, **attributes).tap do |posting|
      posting.job_application.update_columns(status:) unless status == "saved"
    end
  end

  subject(:dashboard) { described_class.new(user, today:).call }

  it "counts applications per status, including zeros, for this user only" do
    posting
    posting
    posting(status: "applied")
    create(:job_posting)

    expect(dashboard[:status_counts]).to eq(
      "saved" => 2, "preparing" => 0, "applied" => 1, "interviewing" => 0, "offer" => 0,
      "accepted" => 0, "rejected" => 0, "no_response" => 0, "withdrawn" => 0
    )
    expect(dashboard[:total]).to eq(3)
  end

  it "lists deadlines in the next 14 days for postings not applied to yet" do
    posting(title: "Later", deadline: today + 10)
    posting(title: "Soon", deadline: today + 2, status: "preparing")
    posting(title: "Already applied", deadline: today + 1, status: "applied")
    posting(title: "Too far", deadline: today + 30)
    posting(title: "Passed", deadline: today - 1)

    expect(dashboard[:upcoming_deadlines].pluck(:title)).to eq(%w[Soon Later])
    expect(dashboard[:upcoming_deadlines].first[:deadline]).to eq("2026-10-22")
  end

  it "lists next actions due within a week, overdue first, skipping closed applications" do
    { "Overdue" => -2, "This week" => 3, "Next month" => 30 }.each do |title, days|
      posting(title:).job_application.update!(next_action: "Follow up", next_action_on: today + days)
    end
    posting(title: "Closed", status: "rejected").job_application.update!(next_action_on: today)

    expect(dashboard[:next_actions].map { |a| [ a[:title], a[:overdue] ] }).to eq([ [ "Overdue", true ], [ "This week", false ] ])
  end

  it "shows the latest status changes" do
    first = posting(title: "First")
    travel 1.hour
    posting(title: "Second")
    travel 1.hour
    first.job_application.transition_to!("applied")

    expect(dashboard[:recent_activity].map { |a| [ a[:title], a[:to_status] ] }).to eq(
      [ %w[First applied], %w[Second saved], %w[First saved] ]
    )
  end
end
