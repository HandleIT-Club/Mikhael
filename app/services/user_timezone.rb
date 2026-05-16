# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Resuelve la zona horaria activa del usuario.
#
# Orden de prioridad:
#   1. Setting per-user "user_timezone" del Current.user (si hay sesión)
#      — autodetectada por el browser (Stimulus la manda la primera vez que
#      abrís la web) o seteada con /zona en Telegram.
#   2. ENV "MIKHAEL_TZ" — fallback para deployments sin user logueado
#      (ej: jobs en background, healthcheck, etc).
#   3. "UTC" — último recurso.
#
# Multi-user: cada usuario puede tener su propia zona, sin pisarse entre sí.
class UserTimezone
  SETTING_KEY = "user_timezone".freeze

  def self.current
    if Current.user
      tz = Setting.get_for(Current.user, SETTING_KEY)
      return tz if tz.present?
    end

    ENV["MIKHAEL_TZ"].presence || "UTC"
  rescue ActiveRecord::StatementInvalid
    ENV.fetch("MIKHAEL_TZ", "UTC")
  end

  def self.set(tz)
    return false unless ActiveSupport::TimeZone[tz]
    return false unless Current.user # sin user no podemos persistir

    Setting.set_for(Current.user, SETTING_KEY, tz)
    Time.zone = tz
    true
  end
end
