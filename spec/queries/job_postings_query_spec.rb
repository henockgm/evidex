require "rails_helper"

RSpec.describe JobPostingsQuery do
  let(:user) { create(:user) }
  let(:today) { Date.new(2026, 10, 20) }

  around { |example| travel_to(today) { example.run } }

  def posting(status: "saved", **attributes)
    create(:job_posting, user:, **attributes).tap do |posting|
      posting.job_application.update_columns(status:) unless status == "saved"
    end
  end

  def titles(params = {})
    described_class.new(user.job_postings, params).call.records.map(&:title)
  end

  it "returns only the user's postings, newest first by default" do
    posting(title: "Old", created_at: 2.days.ago)
    posting(title: "New")
    create(:job_posting, title: "Someone else's")

    expect(titles).to eq(%w[New Old])
  end

  it "filters by one or more statuses, ignoring unknown ones" do
    posting(title: "Saved")
    posting(title: "Applied", status: "applied")
    posting(title: "Interviewing", status: "interviewing")

    expect(titles(status: "applied,interviewing,bogus")).to contain_exactly("Applied", "Interviewing")
    expect(titles(status: "bogus")).to contain_exactly("Saved", "Applied", "Interviewing")
  end

  it "searches title, company and location; every word must match" do
    posting(title: "Rails Developer", company: "Acme", location: "Helsinki")
    posting(title: "Go Developer", company: "Rails Shop", location: "Espoo")
    posting(title: "Designer", company: "Acme", location: "Helsinki")

    expect(titles(q: "rails")).to contain_exactly("Rails Developer", "Go Developer")
    expect(titles(q: "rails helsinki")).to eq([ "Rails Developer" ])
  end

  it "treats LIKE wildcards in the search as plain text" do
    posting(title: "100% Remote Rails")
    posting(title: "Rails")

    expect(titles(q: "100%")).to eq([ "100% Remote Rails" ])
    expect(titles(q: "_")).to be_empty
  end

  it "filters by deadline" do
    posting(title: "Soon", deadline: today + 3)
    posting(title: "Later", deadline: today + 30)
    posting(title: "Passed", deadline: today - 1)
    posting(title: "Open-ended", deadline: nil)

    expect(titles(deadline: "upcoming")).to eq([ "Soon" ])
    expect(titles(deadline: "overdue")).to eq([ "Passed" ])
    expect(titles(deadline: "none")).to eq([ "Open-ended" ])
  end

  it "sorts by deadline with open-ended postings last, and by company" do
    posting(title: "B", company: "beta", deadline: nil)
    posting(title: "A", company: "Alpha", deadline: today + 10)
    posting(title: "C", company: "Gamma", deadline: today + 2)

    expect(titles(sort: "deadline")).to eq(%w[C A B])
    expect(titles(sort: "company")).to eq(%w[A B C])
  end

  it "sorts by next action date" do
    later = posting(title: "Later")
    sooner = posting(title: "Sooner")
    posting(title: "None")
    later.job_application.update!(next_action_on: today + 5)
    sooner.job_application.update!(next_action_on: today + 1)

    expect(titles(sort: "next_action")).to eq(%w[Sooner Later None])
  end

  it "paginates and reports the total" do
    5.times { |i| posting(title: "Posting #{i}", created_at: i.hours.ago) }

    result = described_class.new(user.job_postings, page: "2", per_page: "2").call

    expect(result.records.map(&:title)).to eq([ "Posting 2", "Posting 3" ])
    expect(result).to have_attributes(page: 2, per_page: 2, total: 5)
  end

  it "falls back to safe defaults for bad paging values" do
    result = described_class.new(user.job_postings, page: "-3", per_page: "100000").call
    expect(result).to have_attributes(page: 1, per_page: JobPostingsQuery::MAX_PER_PAGE)
  end
end
