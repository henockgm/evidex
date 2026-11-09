module AnthropicHelpers
  MESSAGES_URL = %r{\Ahttps://api\.anthropic\.com/v1/messages}

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    Ai::Client.reset!
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
    Ai::Client.reset!
  end

  # Stubs one Messages API call answering with `json` as the text block.
  def stub_claude(json: nil, stop_reason: "end_turn", status: 200, body: nil)
    stub_request(:post, MESSAGES_URL).to_return(
      status:,
      headers: { "Content-Type" => "application/json" },
      body: body || {
        id: "msg_test", type: "message", role: "assistant", model: "claude-opus-5-5",
        content: [ { type: "text", text: json.to_json } ],
        stop_reason:, stop_sequence: nil,
        usage: { input_tokens: 1200, output_tokens: 300 }
      }.to_json
    )
  end

  # Requirement lists may be given as plain strings for an English ad; they're
  # sent as { text:, original: nil } like the real schema.
  def extraction_json(overrides = {})
    json = {
      language: "en", title: "Senior Rails Developer", company: "Acme Oy", location: "Helsinki", work_model: "hybrid",
      employment_type: "Full-time", seniority: "Senior", salary: "€5,000–6,000 / month", deadline: "2026-11-30",
      required: [ "5+ years of Ruby on Rails", "PostgreSQL" ], preferred: [ "Experience with pgvector" ],
      responsibilities: [ "Build and maintain REST APIs" ], keywords: %w[Ruby Rails PostgreSQL]
    }.merge(overrides)
    %i[required preferred responsibilities].each do |key|
      json[key] = json[key].map { |item| item.is_a?(String) ? { text: item, original: nil } : item }
    end
    json
  end
end

RSpec.configure do |config|
  config.include AnthropicHelpers
  config.around(:each, :ai) { |example| with_env("ANTHROPIC_API_KEY" => "test-key") { example.run } }
end
