module Ai
  # Thin wrapper around the Anthropic SDK: one place for the model choice,
  # refusal fallbacks and error translation.
  module Client
    class Error < StandardError; end
    class NotConfigured < Error; end
    class Refused < Error; end

    DEFAULT_MODEL = "claude-opus-5-5".freeze
    # Route refused requests to a substitute model chosen by the API.
    FALLBACK_BETA = "server-side-fallback-2026-07-01".freeze

    module_function

    def configured?
      ENV["ANTHROPIC_API_KEY"].present?
    end

    def model
      ENV.fetch("EVIDEX_AI_MODEL", DEFAULT_MODEL)
    end

    # Sends one request expecting JSON that matches `schema`.
    # Returns [parsed_hash, response].
    def structured(system:, prompt:, schema:, effort: :low, max_tokens: 16_000)
      raise NotConfigured, "AI features aren't configured on this server" unless configured?

      response = sdk.beta.messages.create(
        model:,
        max_tokens:,
        system_: system,
        messages: [ { role: "user", content: prompt } ],
        output_config: { effort:, format_: { type: :json_schema, schema: } },
        fallbacks: :default,
        betas: [ FALLBACK_BETA ]
      )

      case response.stop_reason
      when :refusal then raise Refused, "The AI declined to process this text"
      when :max_tokens then raise Error, "The AI response was cut off"
      end

      text = response.content.find { |block| block.type == :text }&.text
      raise Error, "The AI returned no answer" if text.blank?

      [ JSON.parse(text), response ]
    rescue JSON::ParserError
      raise Error, "The AI returned malformed data"
    rescue Anthropic::Errors::RateLimitError
      raise Error, "The AI service is busy; try again in a minute"
    rescue Anthropic::Errors::AuthenticationError, Anthropic::Errors::PermissionDeniedError
      raise NotConfigured, "The AI service rejected this server's API key"
    rescue Anthropic::Errors::APIStatusError => error
      raise Error, "The AI service returned an error (HTTP #{error.status})"
    rescue Anthropic::Errors::APIConnectionError
      raise Error, "Couldn't reach the AI service"
    end

    def sdk
      @sdk ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"), timeout: 120, max_retries: 2)
    end

    def reset!
      @sdk = nil
    end
  end
end
