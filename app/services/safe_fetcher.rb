require "net/http"
require "resolv"

# Fetches a user-supplied URL without letting it reach internal services (SSRF).
#
# - http/https on ports 80 and 443 only, no credentials in the URL
# - the host is resolved once and every address must be public; the
#   connection is then pinned to that address, so a second DNS answer can't
#   swap in a private one (DNS rebinding)
# - redirects are followed manually and each hop is checked again
# - time, size and content-type limits
class SafeFetcher
  class Error < StandardError; end
  class BlockedError < Error; end

  Response = Data.define(:url, :body, :content_type)

  MAX_REDIRECTS = 3
  MAX_BYTES = 2.megabytes
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10
  ALLOWED_PORTS = [ 80, 443 ].freeze
  ALLOWED_CONTENT_TYPES = %w[text/html application/xhtml+xml text/plain].freeze
  USER_AGENT = "EvidexBot/1.0 (+https://github.com/henockgm/evidex)".freeze

  # Ranges IPAddr's predicates don't cover.
  BLOCKED_RANGES = %w[
    0.0.0.0/8 100.64.0.0/10 192.0.0.0/24 192.0.2.0/24 198.18.0.0/15 198.51.100.0/24
    203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 255.255.255.255/32
    ::/128 64:ff9b::/96 100::/64 2001:db8::/32 ff00::/8
  ].map { |range| IPAddr.new(range) }.freeze

  def self.public_address?(ip)
    ip = ip.native # IPv4-mapped IPv6 (::ffff:10.0.0.1) is checked as IPv4
    !(ip.loopback? || ip.private? || ip.link_local? || BLOCKED_RANGES.any? { |range| range.include?(ip) })
  end

  def initialize(resolver: ->(host) { Resolv.getaddresses(host) })
    @resolver = resolver
  end

  def get(url)
    uri = parse(url)

    (MAX_REDIRECTS + 1).times do
      response = request(uri)
      return response unless response.is_a?(URI)

      uri = response
    end
    raise Error, "Too many redirects"
  end

  private
    def parse(url)
      uri = URI.parse(url.to_s.strip)
      raise BlockedError, "Only http and https links are supported" unless uri.is_a?(URI::HTTP) && uri.host.present?
      raise BlockedError, "Links with a username or password aren't supported" if uri.userinfo
      raise BlockedError, "Only the standard ports (80 and 443) are supported" unless ALLOWED_PORTS.include?(uri.port)

      uri
    rescue URI::InvalidURIError
      raise BlockedError, "That doesn't look like a valid link"
    end

    def public_ip_for(host)
      addresses = ip_literal?(host) ? [ IPAddr.new(host) ] : @resolver.call(host).map { |address| IPAddr.new(address) }
      raise Error, "Couldn't find that website" if addresses.empty?
      raise BlockedError, "That address isn't on the public internet" unless addresses.all? { |ip| self.class.public_address?(ip) }

      addresses.first.to_s
    rescue IPAddr::InvalidAddressError
      raise BlockedError, "That address isn't on the public internet"
    end

    def ip_literal?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::InvalidAddressError
      false
    end

    # Returns a Response, or the next URI when the server redirects.
    def request(uri)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.ipaddr = public_ip_for(uri.hostname)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      http.start do
        get = Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => "text/html,application/xhtml+xml,text/plain")
        http.request(get) do |response|
          return redirect_target(uri, response) if response.is_a?(Net::HTTPRedirection)
          raise Error, "The website answered with an error (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

          return Response.new(url: uri.to_s, body: read_body(response), content_type: content_type!(response))
        end
      end
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise Error, "The website took too long to answer"
    rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError => error
      raise Error, "Couldn't connect to the website (#{error.class.name.demodulize})"
    end

    def redirect_target(uri, response)
      location = response["location"].presence or raise Error, "The website sent a redirect without a target"
      parse(uri.merge(location).to_s)
    end

    def content_type!(response)
      type = response.content_type.to_s.downcase
      raise Error, "That link isn't a web page (#{type.presence || 'unknown type'})" unless ALLOWED_CONTENT_TYPES.include?(type)

      type
    end

    def read_body(response)
      content_type!(response)
      raise Error, "That page is too large" if response.content_length.to_i > MAX_BYTES

      body = +""
      response.read_body do |chunk|
        body << chunk
        raise Error, "That page is too large" if body.bytesize > MAX_BYTES
      end
      decode(body, response.type_params["charset"])
    end

    def decode(body, charset)
      body.force_encoding(find_encoding(charset)).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end

    def find_encoding(charset)
      Encoding.find(charset.to_s)
    rescue ArgumentError
      Encoding::UTF_8
    end
end
