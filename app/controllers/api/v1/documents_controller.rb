module Api
  module V1
    class DocumentsController < BaseController
      limit_requests to: 20, within: 1.hour, only: :create, by: -> { Current.user&.id || request.remote_ip }, name: "upload"

      def index
        documents = Current.user.documents.with_attached_file.includes(:chunks).newest_first
        render json: { documents: documents.map { |document| DocumentSerializer.new(document) } }
      end

      def show
        render json: { document: DocumentSerializer.new(document) }
      end

      # multipart/form-data: file, title (defaults to the file name), kind
      def create
        upload = params.require(:file)
        return render_problem(:bad_request, "Missing file") unless upload.is_a?(ActionDispatch::Http::UploadedFile)

        doc = Current.user.documents.new(
          title: params[:title].presence || File.basename(upload.original_filename.to_s, ".*"),
          kind: params[:kind].presence || "cv"
        )
        doc.file.attach(io: upload.tempfile, filename: upload.original_filename, identify: true)

        if doc.save
          doc.make_primary! if doc.kind == "cv" && Current.user.documents.where(primary: true).none?
          render json: { document: DocumentSerializer.new(doc.reload) }, status: :created
        else
          render_validation_errors(doc)
        end
      end

      def update
        attributes = params.expect(document: %i[title kind primary])
        make_primary = ActiveModel::Type::Boolean.new.cast(attributes.delete(:primary))

        Document.transaction do
          document.update!(attributes)
          if make_primary
            document.make_primary!
          elsif make_primary == false
            document.update!(primary: false)
          end
        end
        render json: { document: DocumentSerializer.new(document.reload) }
      rescue ActiveRecord::RecordInvalid
        render_validation_errors(document)
      end

      def destroy
        document.destroy!
        head :no_content
      end

      # Extracted text, page by page (PDFs) or as one page (other formats).
      def text
        render json: { pages: document.text_pages }
      end

      # The passages the document was split into, with their page and section.
      def chunks
        render json: {
          chunks: document.chunks.map { |chunk| chunk.slice(:id, :position, :page, :section, :content).symbolize_keys }
        }
      end

      def retry
        unless document.status == "failed"
          return render_problem(:conflict, "Nothing to retry", detail: "Only documents that failed to process can be retried.")
        end

        document.retry_processing!
        render json: { document: DocumentSerializer.new(document) }, status: :accepted
      end

      # Streams the original file to its owner as an attachment.
      def download
        blob = document.file.blob
        send_data blob.download, filename: blob.filename.to_s, type: blob.content_type, disposition: :attachment
      end

      private
        def document
          @document ||= Current.user.documents.with_attached_file.find(params[:id])
        end
    end
  end
end
