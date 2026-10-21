require "rails_helper"

RSpec.describe SafeFetcher do
  let(:public_ip) { "93.184.215.14" }
  let(:dns) { { "jobs.example.com" => [ public_ip ] } }
  let(:fetcher) { described_class.new(resolver: ->(host) { dns.fetch(host, []) }) }
  let(:html) { { status: 200, body: "<html><body>Job</body></html>", headers: { "Content-Type" => "text/html; charset=utf-8" } } }

  it "fetches a public page" do
    stub_request(:get, "https://jobs.example.com/rails").with(headers: { "User-Agent" => /EvidexBot/ }).to_return(html)

    response = fetcher.get("https://jobs.example.com/rails")

    expect(response).to have_attributes(url: "https://jobs.example.com/rails", content_type: "text/html")
    expect(response.body).to include("Job")
  end

  describe "blocking internal addresses" do
    {
      "loopback" => "127.0.0.1",
      "private 10/8" => "10.1.2.3",
      "private 192.168/16" => "192.168.1.10",
      "cloud metadata (link-local)" => "169.254.169.254",
      "carrier-grade NAT" => "100.64.0.1",
      "unspecified" => "0.0.0.0",
      "IPv6 loopback" => "::1",
      "IPv6 unique local" => "fd00::1",
      "IPv4-mapped IPv6 loopback" => "::ffff:127.0.0.1"
    }.each do |name, ip|
      it "refuses hosts that resolve to #{name} (#{ip})" do
        dns["internal.example.com"] = [ ip ]
        expect { fetcher.get("http://internal.example.com/") }.to raise_error(SafeFetcher::BlockedError)
      end
    end

    it "refuses a host if any of its addresses is internal" do
      dns["mixed.example.com"] = [ public_ip, "10.0.0.5" ]
      expect { fetcher.get("http://mixed.example.com/") }.to raise_error(SafeFetcher::BlockedError)
    end

    it "refuses IP-address links to internal hosts" do
      expect { fetcher.get("http://127.0.0.1/admin") }.to raise_error(SafeFetcher::BlockedError)
      expect { fetcher.get("http://[::1]/") }.to raise_error(SafeFetcher::BlockedError)
    end

    it "checks every redirect" do
      dns["internal.example.com"] = [ "10.0.0.5" ]
      stub_request(:get, "https://jobs.example.com/go").to_return(status: 302, headers: { "Location" => "http://internal.example.com/secret" })

      expect { fetcher.get("https://jobs.example.com/go") }.to raise_error(SafeFetcher::BlockedError)
    end
  end

  describe "URL rules" do
    it "allows only http and https" do
      %w[file:///etc/passwd ftp://jobs.example.com/ gopher://jobs.example.com/ javascript:alert(1)].each do |url|
        expect { fetcher.get(url) }.to raise_error(SafeFetcher::BlockedError), url
      end
    end

    it "allows only the standard ports" do
      expect { fetcher.get("http://jobs.example.com:6379/") }.to raise_error(SafeFetcher::BlockedError, /ports/)
    end

    it "rejects credentials in the URL" do
      expect { fetcher.get("https://user:pass@jobs.example.com/") }.to raise_error(SafeFetcher::BlockedError)
    end
  end

  it "follows a few redirects to public pages" do
    stub_request(:get, "https://jobs.example.com/old").to_return(status: 301, headers: { "Location" => "/new" })
    stub_request(:get, "https://jobs.example.com/new").to_return(html)

    expect(fetcher.get("https://jobs.example.com/old").url).to eq("https://jobs.example.com/new")
  end

  it "stops redirect loops" do
    stub_request(:get, "https://jobs.example.com/loop").to_return(status: 302, headers: { "Location" => "/loop" })
    expect { fetcher.get("https://jobs.example.com/loop") }.to raise_error(SafeFetcher::Error, /Too many redirects/)
  end

  it "rejects files that aren't web pages" do
    stub_request(:get, "https://jobs.example.com/ad.pdf").to_return(status: 200, body: "%PDF", headers: { "Content-Type" => "application/pdf" })
    expect { fetcher.get("https://jobs.example.com/ad.pdf") }.to raise_error(SafeFetcher::Error, /isn't a web page/)
  end

  it "rejects pages over the size limit" do
    stub_request(:get, "https://jobs.example.com/huge")
      .to_return(status: 200, body: "a" * (SafeFetcher::MAX_BYTES + 1), headers: { "Content-Type" => "text/html" })
    expect { fetcher.get("https://jobs.example.com/huge") }.to raise_error(SafeFetcher::Error, /too large/)
  end

  it "reports HTTP errors and timeouts" do
    stub_request(:get, "https://jobs.example.com/gone").to_return(status: 404)
    stub_request(:get, "https://jobs.example.com/slow").to_timeout

    expect { fetcher.get("https://jobs.example.com/gone") }.to raise_error(SafeFetcher::Error, /HTTP 404/)
    expect { fetcher.get("https://jobs.example.com/slow") }.to raise_error(SafeFetcher::Error)
  end

  it "reports hosts that don't resolve" do
    expect { fetcher.get("https://nowhere.example.com/") }.to raise_error(SafeFetcher::Error, /Couldn't find/)
  end
end
