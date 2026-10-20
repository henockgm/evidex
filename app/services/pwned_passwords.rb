require "net/http"

# Checks a password against Have I Been Pwned using k-anonymity: only the first
# five characters of its SHA-1 hash leave the server. Fails open (returns false)
# if the service is unreachable, so an outage never blocks sign-ups.
module PwnedPasswords
  ENDPOINT = "https://api.pwnedpasswords.com/range/".freeze
  TIMEOUT = 2

  def self.breached?(password)
    digest = OpenSSL::Digest::SHA1.hexdigest(password).upcase
    prefix, suffix = digest[0, 5], digest[5..]

    response_lines(prefix).any? do |line|
      hash_suffix, count = line.strip.split(":")
      hash_suffix == suffix && count.to_i.positive? # padding entries have count 0
    end
  rescue StandardError => error
    Rails.logger.warn("Pwned Passwords check skipped: #{error.class}: #{error.message}")
    false
  end

  def self.response_lines(prefix)
    uri = URI("#{ENDPOINT}#{prefix}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.get(uri.request_uri, "Add-Padding" => "true", "User-Agent" => "Evidex")
    end
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response.body.lines
  end
  private_class_method :response_lines
end
