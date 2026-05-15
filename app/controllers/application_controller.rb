# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class ApplicationController < ActionController::Base
  include AppAuthentication
  include RateLimitable

  allow_browser versions: :modern

  # Límite global para rutas web. Se aplica por IP.
  # Se define como método nombrado para que Api::V1::BaseController pueda
  # saltearlo con skip_before_action sin afectar los límites de API.
  before_action :check_web_rate_limit

  private

  def check_web_rate_limit
    rate_limiting(
      to:     ENV.fetch("RATE_LIMIT_WEB_PER_MIN", "100").to_i,
      within: 1.minute,
      by:     -> { request.remote_ip },
      with:   -> { render_rate_limit_exceeded(30, identifier: request.remote_ip) },
      store:  RATE_LIMIT_STORE,
      name:   "web",
      scope:  controller_path
    )
  end
end
