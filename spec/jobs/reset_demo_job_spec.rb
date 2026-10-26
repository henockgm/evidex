require "rails_helper"
require "fugit"

RSpec.describe ResetDemoJob do
  it "rebuilds the demo account when there is one" do
    demo = create(:user, demo: true)
    create(:job_posting, user: demo, title: "Added by a visitor")

    described_class.perform_now

    expect(JobPosting.where(user: demo).pluck(:title)).not_to include("Added by a visitor")
    expect(JobPosting.where(user: demo).count).to eq(3)
  end

  it "doesn't create a demo account on a server without one" do
    expect { described_class.perform_now }.not_to change(User, :count)
  end

  it "is scheduled nightly in production" do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "reset_demo_account")
    expect(schedule).to include("class" => "ResetDemoJob")
    expect(Fugit.parse(schedule["schedule"])).to be_present
  end
end
