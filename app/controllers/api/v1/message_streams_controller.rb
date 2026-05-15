# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Api
  module V1
    # Endpoint SSE para streaming de respuestas al CLI.
    # POST /api/v1/conversations/:conversation_id/messages/stream
    # Devuelve text/event-stream con eventos:
    #   data: {"chunk":"texto"}
    #   data: {"done":true,"model":"...","provider":"..."}
    #   data: {"error":"..."}
    class MessageStreamsController < BaseController
      include ActionController::Live

      before_action :set_conversation

      def create
        content = params.dig(:message, :content).to_s
        if content.strip.empty?
          render json: { error: "content es requerido" }, status: :unprocessable_content
          return
        end

        response.headers["Content-Type"]      = "text/event-stream"
        response.headers["Cache-Control"]     = "no-cache"
        response.headers["X-Accel-Buffering"] = "no"

        sse = SSE.new(response.stream, retry: 300, event: "message")

        result = CreateMessage.new.call(
          conversation: @conversation,
          content:      content,
          on_chunk:     ->(chunk) { sse.write({ chunk: chunk }.to_json) }
        )

        result.either(
          ->(ai_response) { sse.write({ done: true, model: ai_response.model, provider: ai_response.provider }.to_json) },
          ->(error)       { sse.write({ error: error.to_s }.to_json) }
        )
      rescue ActionController::Live::ClientDisconnected
        # El cliente cerró la conexión — normal, no es un error.
        Rails.logger.info("SSE client disconnected for conversation #{@conversation&.id}")
      ensure
        sse&.close
      end

      private

      def set_conversation
        @conversation = Conversation.find(params[:conversation_id])
      end
    end
  end
end
