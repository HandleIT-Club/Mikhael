# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Api
  module V1
    # Base de toda la API JSON. Autenticación por Bearer token de User
    # (`Authorization: Bearer <user.api_token>`).
    #
    # Las subclases que tienen su propio mecanismo de auth (ej:
    # ActionsController autentica con token de Device, no de User) llaman
    # `skip_before_action :authenticate_user_via_api_token!`.
    class BaseController < ApplicationController
      protect_from_forgery with: :null_session

      # No usamos cookies acá — solo bearer tokens. Salteamos la auth web
      # de la clase padre (que redirige al login form) y aplicamos la propia.
      skip_before_action :authenticate_user!
      skip_before_action :check_web_rate_limit

      before_action :authenticate_user_via_api_token!

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "No encontrado" }, status: :not_found
      end

      private

      def authenticate_user_via_api_token!
        token = request.headers["Authorization"].to_s.sub(/\ABearer\s+/, "")
        user  = User.find_by_api_token(token)

        if user
          Current.user = user
        else
          render json: { error: "API token inválido o ausente" }, status: :unauthorized
        end
      end

      def render_error(code, status: :unprocessable_entity)
        render json: { error: code }, status: status
      end
    end
  end
end
