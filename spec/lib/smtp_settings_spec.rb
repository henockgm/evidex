require "rails_helper"
require "evidex/smtp_settings"

RSpec.describe Evidex::SmtpSettings do
  let(:env) do
    { "SMTP_ADDRESS" => "smtp.example.com", "SMTP_USERNAME" => "user@example.com", "SMTP_PASSWORD" => "secret" }
  end

  it "builds STARTTLS settings on port 587 by default" do
    expect(described_class.from(env)).to include(
      address: "smtp.example.com", port: 587, user_name: "user@example.com", password: "secret",
      authentication: :login, enable_starttls: true
    )
  end

  it "uses SMTP_PORT when given" do
    expect(described_class.from(env.merge("SMTP_PORT" => "2525"))[:port]).to eq(2525)
  end

  it "returns nil when no SMTP server is configured" do
    expect(described_class.from({})).to be_nil
  end

  it "refuses a half-configured server and names what is missing" do
    expect { described_class.from(env.except("SMTP_PASSWORD")) }
      .to raise_error(KeyError, /missing SMTP_PASSWORD/)
  end
end
