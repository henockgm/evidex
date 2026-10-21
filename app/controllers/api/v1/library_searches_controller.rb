module Api
  module V1
    class LibrarySearchesController < BaseController
      limit_requests to: 30, within: 1.minute, by: -> { Current.user&.id || request.remote_ip }

      def show
        results = Library::Search.new(Current.user, params[:q]).call
        render json: {
          results: results.map do |result|
            chunk = result.chunk
            {
              chunk_id: chunk.id,
              document_id: chunk.document_id,
              document_title: chunk.document.title,
              page: chunk.page,
              section: chunk.section,
              content: chunk.content,
              score: result.score,
              matched_by: result.matched_by.map(&:to_s)
            }
          end
        }
      end
    end
  end
end
