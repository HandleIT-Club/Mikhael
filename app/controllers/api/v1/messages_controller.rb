module Api
  module V1
    class MessagesController < BaseController
      before_action :set_conversation

      def create
        result = CreateMessage.new.call(
          conversation: @conversation,
          content:      params.dig(:message, :content).to_s
        )

        result.either(
          ->(ai_response) { render json: { content: ai_response.content, model: ai_response.model, provider: ai_response.provider }, status: :created },
          ->(error)       { render_error(error, status: error_status(error)) }
        )
      end

      private

      def set_conversation
        @conversation = Conversation.find(params[:conversation_id])
      end

      def error_status(error)
        case error
        when :invalid_input    then :unprocessable_entity
        when :ollama_unavailable then :service_unavailable
        when :rate_limited       then :too_many_requests
        when :invalid_api_key    then :unauthorized
        else :internal_server_error
        end
      end
    end
  end
end
