# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Resuelve la zona horaria activa del usuario de Mikhael.
#
# Orden de prioridad:
#   1. Setting "user_timezone" — autodetectada por el browser (Stimulus la
#      manda la primera vez que abrís la web) o seteada manualmente.
#   2. ENV "MIKHAEL_TZ" — fallback para deployments sin browser
#      (ej: server headless usando solo Telegram/CLI).
#   3. "UTC" — último recurso.
#
# Se aplica al booteo (config/application.rb) y a TelegramContextBuilder
# para que el chat AI vea la zona correcta sin importar la superficie.
class UserTimezone
  SETTING_KEY = "user_timezone".freeze

  def self.current
    Setting.get(SETTING_KEY).presence ||
      ENV["MIKHAEL_TZ"].presence ||
      "UTC"
  rescue ActiveRecord::StatementInvalid
    # Si la tabla settings no existe aún (ej. durante migraciones),
    # caemos al ENV sin reventar.
    ENV.fetch("MIKHAEL_TZ", "UTC")
  end

  def self.set(tz)
    return false unless ActiveSupport::TimeZone[tz]

    Setting.set(SETTING_KEY, tz)
    Time.zone = tz
    true
  end
end
