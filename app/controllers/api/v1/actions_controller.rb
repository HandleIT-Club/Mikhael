# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Api
  module V1
    class ActionsController < BaseController
      skip_before_action :require_app_password
      before_action :authenticate_device

      def create
        context = params[:context].to_s.strip
        return render json: { error: "context es requerido" }, status: :unprocessable_entity if context.blank?

        result = DispatchAction.new.call(device: @device, context: context)

        result.either(
          ->(response) { notify_telegram(@device, response); render json: response, status: :ok },
          ->(error)    { render json: { error: error }, status: error_status(error) }
        )
      end

      private

      def authenticate_device
        token   = request.headers["Authorization"].to_s.sub(/\ABearer\s+/, "")
        @device = Device.find_by(token: token)
        render json: { error: "Token inválido" }, status: :unauthorized unless @device
      end

      def notify_telegram(device, response)
        return unless response[:action].present?
        emoji  = response[:requires_confirmation] ? "⚠️" : "📡"
        text   = "#{emoji} *#{device.name}* → `#{response[:action]}`"
        text  += "\nValor: #{response[:value]}" if response[:value]
        text  += "\n_#{response[:reason]}_"
        TelegramClient.send_message(text)
      end

      def error_status(error)
        case error
        when :all_models_exhausted then :service_unavailable
        else :internal_server_error
        end
      end
    end
  end
end
