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

  def self.current(user: Current.user)
    if user
      tz = Setting.get_for(user, SETTING_KEY)
      return tz if tz.present?
    end

    ENV["MIKHAEL_TZ"].presence || "UTC"
  rescue ActiveRecord::StatementInvalid
    ENV.fetch("MIKHAEL_TZ", "UTC")
  end

  # Persiste la zona para el user dado. Si user es nil, no hay dónde guardar.
  # Acepta nombres IANA ("America/Argentina/Buenos_Aires") o aliases de
  # ActiveSupport ("Buenos Aires", "Madrid", etc.).
  #
  # El user explícito (en lugar de leer Current.user) facilita testear y
  # evita mutar state global desde callers que ya tienen el user a mano.
  def self.set(tz, user: Current.user)
    return false unless ActiveSupport::TimeZone[tz]
    return false unless user

    Setting.set_for(user, SETTING_KEY, tz)
    Time.zone = tz
    true
  end
end
