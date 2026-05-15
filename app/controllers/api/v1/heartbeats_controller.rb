# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Api
  module V1
    class HeartbeatsController < BaseController
      skip_before_action :require_app_password
      before_action :authenticate_device

      # POST /api/v1/heartbeat
      # El dispositivo llama esto periódicamente (cada ~30s) para marcar que está online.
      def create
        @device.touch_last_seen!
        render json: { ok: true, device_id: @device.device_id, last_seen_at: @device.last_seen_at }
      end

      private

      def authenticate_device
        token   = request.headers["Authorization"].to_s.sub(/\ABearer\s+/, "")
        @device = Device.find_by(token: token)
        render json: { error: "Token inválido" }, status: :unauthorized unless @device
      end
    end
  end
end
