# Turns a fetched job ad page into a draft posting. Prefers schema.org
# JobPosting data (JSON-LD), which most job boards embed for search engines,
# and falls back to the page's title and readable text.
class PostingPageParser
  Draft = Data.define(:title, :company, :location, :work_model, :deadline, :description, :structured)

  BLOCK_TAGS = %w[p div section article li ul ol h1 h2 h3 h4 h5 h6 br tr table header footer main blockquote pre].freeze
  NOISE_SELECTOR = "script, style, noscript, template, svg, nav, header, footer, aside, form, iframe, [hidden], [aria-hidden='true']".freeze

  def self.parse(html, url:)
    new(html, url:).parse
  end

  def initialize(html, url:)
    @document = Nokogiri::HTML5(html)
    @url = url
  end

  def parse
    data = job_posting_json_ld
    data ? from_structured_data(data) : from_page
  end

  private
    def job_posting_json_ld
      @document.css('script[type="application/ld+json"]').each do |script|
        found = find_job_posting(JSON.parse(script.text))
        return found if found
      rescue JSON::ParserError
        next
      end
      nil
    end

    def find_job_posting(node)
      case node
      when Array then node.lazy.filter_map { |item| find_job_posting(item) }.first
      when Hash
        return node if Array(node["@type"]).include?("JobPosting")

        find_job_posting(node["@graph"])
      end
    end

    def from_structured_data(data)
      Draft.new(
        title: clean(data["title"]) || page_title,
        company: clean(organization_name(data["hiringOrganization"])) || site_name,
        location: location(data["jobLocation"]),
        work_model: Array(data["jobLocationType"]).include?("TELECOMMUTE") ? "remote" : nil,
        deadline: date(data["validThrough"]),
        description: html_to_text(data["description"].to_s).presence || readable_text,
        structured: true
      )
    end

    def from_page
      Draft.new(title: page_title, company: site_name, location: nil, work_model: nil, deadline: nil,
        description: readable_text, structured: false)
    end

    def organization_name(organization)
      organization.is_a?(Hash) ? organization["name"] : organization
    end

    def location(job_location)
      places = Array.wrap(job_location).filter_map do |place|
        address = place.is_a?(Hash) ? place["address"] : nil
        next clean(address) if address.is_a?(String)
        next unless address.is_a?(Hash)

        country = address["addressCountry"]
        country = country["name"] if country.is_a?(Hash)
        [ address["addressLocality"], address["addressRegion"], country ].filter_map { |part| clean(part) }.uniq.join(", ").presence
      end
      places.uniq.join("; ").first(200).presence
    end

    def date(value)
      Date.parse(value.to_s) if value.present?
    rescue Date::Error
      nil
    end

    def page_title
      clean(meta("og:title")) || clean(@document.at_css("title")&.text)
    end

    def site_name
      clean(meta("og:site_name")) || URI(@url).host.to_s.delete_prefix("www.")
    end

    def meta(property)
      @document.at_css(%(meta[property="#{property}"], meta[name="#{property}"]))&.[]("content")
    end

    def readable_text
      root = (@document.at_css("main") || @document.at_css("article") || @document.at_css("body"))&.dup
      return "" unless root

      root.css(NOISE_SELECTOR).each(&:remove)
      node_text(root)
    end

    def html_to_text(html)
      node_text(Nokogiri::HTML5.fragment(html))
    end

    # Text with line breaks at block elements, so lists and paragraphs survive.
    def node_text(node)
      node.css(BLOCK_TAGS.join(", ")).each do |block|
        block.add_previous_sibling("\n")
        block.add_next_sibling("\n")
      end
      node.css("li").each { |item| item.prepend_child("• ") }

      node.text.gsub(/[ \t ]+/, " ").gsub(/ *\n */, "\n").gsub(/\n{3,}/, "\n\n").strip
        .first(JobPosting::DESCRIPTION_MAX_LENGTH)
    end

    def clean(value)
      value.is_a?(String) ? value.squish.first(200).presence : nil
    end
end
