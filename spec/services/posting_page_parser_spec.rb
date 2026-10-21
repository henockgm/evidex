require "rails_helper"

RSpec.describe PostingPageParser do
  let(:url) { "https://www.jobs.example.com/acme/123" }

  it "reads schema.org JobPosting data" do
    json_ld = {
      "@context" => "https://schema.org",
      "@graph" => [
        { "@type" => "WebPage", "name" => "Careers" },
        {
          "@type" => "JobPosting",
          "title" => "Senior Ruby on Rails Developer",
          "hiringOrganization" => { "@type" => "Organization", "name" => "Acme Oy" },
          "jobLocation" => [ { "@type" => "Place", "address" => { "addressLocality" => "Helsinki", "addressCountry" => "FI" } } ],
          "jobLocationType" => "TELECOMMUTE",
          "validThrough" => "2026-11-30T23:59:00+02:00",
          "description" => "<p>Join us.</p><h3>Requirements</h3><ul><li>Rails</li><li>PostgreSQL</li></ul>"
        }
      ]
    }
    html = %(<html><head><script type="application/ld+json">#{json_ld.to_json}</script></head><body>ignored</body></html>)

    draft = described_class.parse(html, url:)

    expect(draft).to have_attributes(
      title: "Senior Ruby on Rails Developer", company: "Acme Oy", location: "Helsinki, FI",
      work_model: "remote", deadline: Date.new(2026, 11, 30), structured: true
    )
    expect(draft.description).to eq("Join us.\n\nRequirements\n\n• Rails\n\n• PostgreSQL")
  end

  it "skips broken JSON-LD blocks" do
    html = <<~HTML
      <script type="application/ld+json">{ not json</script>
      <script type="application/ld+json">{"@type":"JobPosting","title":"Rails Dev","description":"Text"}</script>
    HTML

    expect(described_class.parse(html, url:)).to have_attributes(title: "Rails Dev", structured: true)
  end

  it "falls back to the page title and main text" do
    html = <<~HTML
      <html>
        <head><title>Rails Developer – Acme</title><meta property="og:site_name" content="Acme Careers"></head>
        <body>
          <nav>Home Jobs About</nav>
          <main><h1>Rails Developer</h1><p>We build   APIs.</p><script>track()</script><ul><li>Ruby</li></ul></main>
          <footer>© Acme</footer>
        </body>
      </html>
    HTML

    draft = described_class.parse(html, url:)

    expect(draft).to have_attributes(title: "Rails Developer – Acme", company: "Acme Careers", structured: false, deadline: nil)
    expect(draft.description).to eq("Rails Developer\n\nWe build APIs.\n\n• Ruby")
  end

  it "uses the domain as the company when the page names none" do
    expect(described_class.parse("<title>Job</title><p>Text</p>", url:).company).to eq("jobs.example.com")
  end
end
