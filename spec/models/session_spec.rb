require "rails_helper"

RSpec.describe Session do
  let(:session) { create(:session) }

  it "stores only a digest of the token" do
    expect(session.token).to be_present
    expect(session.token_digest).to eq(described_class.digest(session.token))
    expect(session.token_digest).not_to eq(session.token)
  end

  it "is found by its token" do
    expect(described_class.find_by_token(session.token)).to eq(session)
    expect(described_class.find_by_token("wrong")).to be_nil
    expect(described_class.find_by_token(nil)).to be_nil
  end

  it "expires after 14 days of inactivity" do
    token = session.token
    travel 15.days do
      expect(described_class.find_by_token(token)).to be_nil
    end
  end

  it "expires 30 days after sign-in even when active" do
    session.update_columns(created_at: 31.days.ago, last_active_at: 1.minute.ago)
    expect(described_class.find_by_token(session.token)).to be_nil
  end
end
