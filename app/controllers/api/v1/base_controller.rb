# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Api
  module V1
    class BaseController < ApplicationController
      protect_from_forgery with: :null_session

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "No encontrado" }, status: :not_found
      end

      private

      def render_error(code, status: :unprocessable_entity)
        render json: { error: code }, status: status
      end
    end
  end
end
