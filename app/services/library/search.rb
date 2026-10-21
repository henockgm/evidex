module Library
  # Searches one user's library by meaning (vector similarity) and by words
  # (PostgreSQL full-text), then merges both rankings with Reciprocal Rank
  # Fusion, which needs no weights to tune.
  class Search
    Result = Data.define(:chunk, :score, :matched_by)

    CANDIDATES = 20
    RRF_K = 60 # standard RRF damping constant
    MAX_QUERY_LENGTH = 500

    def initialize(user, query, limit: 10)
      @user = user
      @query = query.to_s.squish.first(MAX_QUERY_LENGTH)
      @limit = limit
    end

    def call
      return [] if @query.blank?

      rankings = { semantic: semantic_ids, keyword: keyword_ids }
      scores = Hash.new(0.0)
      matched_by = Hash.new { |hash, key| hash[key] = [] }
      rankings.each do |kind, ids|
        ids.each_with_index do |id, rank|
          scores[id] += 1.0 / (RRF_K + rank + 1)
          matched_by[id] << kind
        end
      end

      top_ids = scores.sort_by { |id, score| [ -score, id ] }.first(@limit).map(&:first)
      chunks = scope.includes(:document).where(id: top_ids).index_by(&:id)
      top_ids.filter_map do |id|
        chunk = chunks[id] or next
        Result.new(chunk:, score: scores[id].round(4), matched_by: matched_by[id])
      end
    end

    private
      # Always limited to the user's own, fully processed documents.
      def scope
        DocumentChunk.where(user_id: @user.id).joins(:document).where(documents: { status: "ready" })
      end

      def semantic_ids
        vector = Embedder.embed_query(@query)
        scope.where.not(embedding: nil).nearest_neighbors(:embedding, vector, distance: "cosine")
          .first(CANDIDATES).select { |chunk| chunk.neighbor_distance <= Embedder.max_distance }.map(&:id)
      end

      def keyword_ids
        tsquery = ActiveRecord::Base.sanitize_sql_array([ "websearch_to_tsquery('simple', ?)", @query ])
        scope.where("document_chunks.search_vector @@ #{tsquery}")
          .order(Arel.sql("ts_rank_cd(document_chunks.search_vector, #{tsquery}) DESC, document_chunks.id"))
          .limit(CANDIDATES).pluck(:id)
      end
  end
end
