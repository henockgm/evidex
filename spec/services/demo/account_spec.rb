require "rails_helper"

RSpec.describe Demo::Account do
  it "builds the demo account from db/demo without calling the AI" do
    expect(Ai::Client).not_to receive(:structured)

    user = described_class.reset!

    expect(user).to have_attributes(demo: true, email_address: "demo@evidex.invalid", name: "Alex Example", password_digest: nil)
    expect(user).to be_verified
    expect(user.documents.map(&:status)).to all(eq("ready"))
    expect(user.document_chunks.count).to be > 5
    expect(user.job_postings.map { |posting| posting.job_application.status }).to contain_exactly("interviewing", "applied", "saved")

    report = user.job_postings.find_by!(company: "Polar Freight Oy").match_reports.sole
    expect(report).to have_attributes(status: "done", version: 1)
    expect(report.counts).to eq("evidenced" => 6, "transferable" => 2, "gap" => 2)
    expect(report.matches.flat_map(&:citations)).to all(have_attributes(document_chunk: be_present))
    expect(report.matches.map(&:requirement)).to all(be_present)
  end

  it "throws away what visitors changed on the next reset" do
    user = described_class.reset!
    create(:job_posting, user:, title: "Added by a visitor")
    user.job_postings.first.update!(title: "Renamed by a visitor")

    expect(described_class.reset!).to eq(user)
    expect(JobPosting.where(user:).pluck(:title)).to contain_exactly(
      "Senior Ruby on Rails Developer", "Backend Engineer, Payments", "Full-Stack Developer"
    )
    expect(User.where(demo: true).count).to eq(1)
  end

  it "ends visitors' sessions older than a day" do
    user = create(:user, demo: true)
    old = user.sessions.create!(created_at: 2.days.ago)
    recent = user.sessions.create!

    described_class.reset!

    expect(Session.exists?(old.id)).to be(false)
    expect(Session.exists?(recent.id)).to be(true)
  end

  it "is the only demo account" do
    create(:user, demo: true)
    expect { create(:user, demo: true) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
