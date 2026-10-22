# A readable name for a browser, such as "Chrome on macOS", from its user agent.
# Mirrors describeDevice() in the SPA's security page.
module DeviceName
  BROWSERS = { "Edge" => %r{Edg/}, "Firefox" => %r{Firefox/}, "Chrome" => %r{Chrome/}, "Safari" => %r{Safari/} }.freeze
  # Phones first: iOS user agents also say "like Mac OS X", Android ones "Linux".
  SYSTEMS = { "iOS" => /iPhone|iPad/, "Android" => /Android/, "macOS" => /Mac OS X/, "Windows" => /Windows/, "Linux" => /Linux/ }.freeze

  def self.for(user_agent)
    return "Unknown device" if user_agent.blank?

    browser = BROWSERS.find { |_, pattern| user_agent.match?(pattern) }&.first || user_agent.first(40)
    system = SYSTEMS.find { |_, pattern| user_agent.match?(pattern) }&.first
    system ? "#{browser} on #{system}" : browser
  end
end
