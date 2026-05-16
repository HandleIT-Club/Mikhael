# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Api
  module V1
    class ActionsController < BaseController
      # Este endpoint NO usa user API token — usa el Device token (los devices
      # ESP32 no son users, son hardware con su propio Bearer token).
      skip_before_action :authenticate_user_via_api_token!

      # Rate limit por token: cada dispositivo tiene su propio contador.
      # Corre antes de authenticate_device para proteger también contra tokens inválidos.
      rate_limit to:     ENV.fetch("RATE_LIMIT_ACTION_PER_MIN", "60").to_i,
                 within: 1.minute,
                 by:     -> { request.headers["Authorization"].to_s.delete_prefix("Bearer ") },
                 with:   -> {
                   token = request.headers["Authorization"].to_s.delete_prefix("Bearer ")
                   render_rate_limit_exceeded(30, identifier: token)
                 },
                 store:  RATE_LIMIT_STORE

      before_action :authenticate_device

      def create
        context = params[:context].to_s.strip
        return render json: { error: "context es requerido" }, status: :unprocessable_entity if context.blank?

        @device.touch_last_seen!
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

      # Notifica a TODOS los admins con telegram_chat_id linkeado. Los devices
      # son recursos compartidos del hogar — todos los admins quieren saber
      # cuando un device hace algo. Si el día de mañana querés notificar solo
      # a uno, se puede agregar Device#notify_user.
      def notify_telegram(device, response)
        return unless response[:action].present?
        emoji = response[:requires_confirmation] ? "⚠️" : "📡"
        text  = "#{emoji} *#{device.name}* → `#{response[:action]}`"
        text += "\nValor: #{response[:value]}" if response[:value]
        text += "\n_#{response[:reason]}_"

        User.where(admin: true).where.not(telegram_chat_id: nil).find_each do |admin|
          TelegramClient.send_message(text, chat_id: admin.telegram_chat_id)
        end
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
