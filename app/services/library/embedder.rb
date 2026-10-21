module Library
  # Turns text into vectors for similarity search. The backend is chosen with
  # EVIDEX_EMBEDDINGS: "local" (default) runs a small open-source model in this
  # process, so document text never leaves the server; "fake" is a fast,
  # deterministic stand-in for tests.
  module Embedder
    DIMENSIONS = 384

    module_function

    def backend
      @backend ||= case ENV.fetch("EVIDEX_EMBEDDINGS", Rails.env.test? ? "fake" : "local")
      when "local" then Local.new
      when "fake" then Fake.new
      else raise ArgumentError, "Unknown EVIDEX_EMBEDDINGS backend"
      end
    end

    def reset!
      @backend = nil
    end

    def model_name = backend.model_name

    # Cosine distance above which a passage counts as unrelated to a query.
    def max_distance
      ENV["EVIDEX_SEARCH_MAX_DISTANCE"].presence&.to_f || backend.default_max_distance
    end

    def embed_passages(texts) = backend.embed_passages(texts)
    def embed_query(text) = backend.embed_query(text)

    # multilingual-e5-small (quantized ONNX, ~118 MB, downloaded once from
    # Hugging Face into ~/.cache/informers). Understands English and Finnish.
    class Local
      MODEL = "Xenova/multilingual-e5-small".freeze
      BATCH_SIZE = 16

      def initialize
        @mutex = Mutex.new
      end

      def model_name = MODEL

      # Measured on sample CVs: related passages scored 0.13-0.19,
      # unrelated queries 0.20 and above.
      def default_max_distance = 0.2

      # e5 models expect "passage: " / "query: " prefixes.
      def embed_passages(texts)
        texts.each_slice(BATCH_SIZE).flat_map { |batch| run(batch.map { |text| "passage: #{text}" }) }
      end

      def embed_query(text)
        run([ "query: #{text}" ]).first
      end

      private
        def run(inputs)
          @mutex.synchronize { pipeline.(inputs) }
        end

        def pipeline
          @pipeline ||= Informers.pipeline("embedding", MODEL, quantized: true)
        end
    end

    # Hashes words into a normalised vector: texts sharing words are close.
    # Good enough to test ranking without downloading a model.
    class Fake
      def model_name = "fake"
      def default_max_distance = 0.9

      def embed_passages(texts) = texts.map { |text| vector(text) }
      def embed_query(text) = vector(text)

      private
        def vector(text)
          values = Array.new(DIMENSIONS, 0.0)
          text.downcase.scan(/\p{Alnum}+/).each { |word| values[Zlib.crc32(word) % DIMENSIONS] += 1.0 }
          norm = Math.sqrt(values.sum { |value| value * value })
          norm.zero? ? values : values.map { |value| value / norm }
        end
    end
  end
end
