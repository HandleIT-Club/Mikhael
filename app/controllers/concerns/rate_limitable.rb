# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Helpers compartidos por todos los controllers que aplican rate limiting.
module RateLimitable
  extend ActiveSupport::Concern

  private

  # Renderiza 429 con Retry-After header y body JSON estándar.
  # Nunca loguea el identificador completo — solo los primeros 8 chars.
  def render_rate_limit_exceeded(retry_after_seconds, identifier:)
    short_id = identifier.to_s.first(8)
    Rails.logger.warn("[RateLimit] #{controller_path}##{action_name} — id: #{short_id}…")
    response.headers["Retry-After"] = retry_after_seconds.to_s
    render json: { error: "rate_limit_exceeded", retry_after: retry_after_seconds },
           status: :too_many_requests
  end
end
