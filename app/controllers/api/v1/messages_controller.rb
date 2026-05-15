# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Api
  module V1
    class MessagesController < BaseController
      rate_limit to:     ENV.fetch("RATE_LIMIT_MESSAGES_PER_MIN", "30").to_i,
                 within: 1.minute,
                 by:     -> { request.remote_ip },
                 with:   -> { render_rate_limit_exceeded(30, identifier: request.remote_ip) },
                 store:  RATE_LIMIT_STORE,
                 only:   :create

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
        when :invalid_input        then :unprocessable_entity
        when :ollama_unavailable   then :service_unavailable
        when :all_models_exhausted then :service_unavailable
        when :rate_limited         then :too_many_requests
        when :invalid_api_key      then :unauthorized
        else :internal_server_error
        end
      end
    end
  end
end
