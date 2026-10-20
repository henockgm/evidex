require "rails_helper"

RSpec.describe PwnedPasswords do
  # SHA-1("password1234") = E6B6AFBD6D76BB5D2041542D7D2E3FAC5BB05593
  let(:range_url) { "https://api.pwnedpasswords.com/range/E6B6A" }

  it "sends only the hash prefix and finds a breached password" do
    stub = stub_request(:get, range_url).with(headers: { "Add-Padding" => "true" })
      .to_return(body: "0000000000000000000000000000000000A:0\r\nFBD6D76BB5D2041542D7D2E3FAC5BB05593:2410\r\n")

    expect(described_class.breached?("password1234")).to be(true)
    expect(stub).to have_been_requested
  end

  it "ignores zero-count padding entries" do
    stub_request(:get, range_url).to_return(body: "FBD6D76BB5D2041542D7D2E3FAC5BB05593:0\r\n")
    expect(described_class.breached?("password1234")).to be(false)
  end

  it "fails open when the service is unavailable" do
    stub_request(:get, range_url).to_timeout
    expect(described_class.breached?("password1234")).to be(false)
  end
end
