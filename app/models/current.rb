# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Thread-local state per request. Setteado por la concern Authentication
# desde el SessionsController (web) o por el Bearer token (API).
#
# Uso típico:
#   Current.user          # → User actual, o nil si no hay sesión
#   Current.user.reminders
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end
