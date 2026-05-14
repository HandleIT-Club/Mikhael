# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module AppAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :require_app_password
  end

  private

  def require_app_password
    password = ENV["MIKHAEL_PASSWORD"].presence
    return unless password

    authenticate_or_request_with_http_basic("Mikhael") do |_user, given|
      ActiveSupport::SecurityUtils.secure_compare(given.to_s, password)
    end
  end
end
