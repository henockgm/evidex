require "rails_helper"

RSpec.describe AdLink do
  describe ".normalize" do
    it "ignores case in the scheme and host, the fragment and a trailing slash" do
      expect(described_class.normalize("HTTPS://Jobs.Example.com/Acme/Rails-Developer/#apply"))
        .to eq("https://jobs.example.com/Acme/Rails-Developer")
    end

    it "drops tracking parameters and keeps the ones that pick the job" do
      expect(described_class.normalize("https://jobs.ashbyhq.com/acme?utm_source=linkedin&ashby_jid=abc123&gclid=x&feedId=7&fbclid=y"))
        .to eq("https://jobs.ashbyhq.com/acme?ashby_jid=abc123")
    end

    it "doesn't depend on the order of the parameters" do
      expect(described_class.normalize("https://example.com/job?b=2&a=1"))
        .to eq(described_class.normalize("https://example.com/job?a=1&b=2"))
    end

    it "drops the default port but keeps others" do
      expect(described_class.normalize("https://example.com:443/job")).to eq("https://example.com/job")
      expect(described_class.normalize("http://example.com:8080/job")).to eq("http://example.com:8080/job")
    end

    it "returns nil for blank or non-web links" do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize(" ")).to be_nil
      expect(described_class.normalize("mailto:jobs@example.com")).to be_nil
      expect(described_class.normalize("not a link")).to be_nil
    end
  end
end
