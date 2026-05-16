# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Intercepta mensajes que tienen una respuesta determinística desde Rails,
# antes de que lleguen al AI. Si Rails tiene el dato, lo respondemos desde
# Rails — el AI nunca tiene chance de alucinar.
#
# Devuelve nil → caller sigue al AI.
# Devuelve Result → caller usa esa respuesta (y la persiste en la conversación).
#
# Compartido entre TelegramMessageHandler y MessagesController (web).
class MessageIntentRouter
  # Pregunta de hora — exige verbo de existencia después de "hora" para evitar
  # falsos positivos como "qué hora cierra la farmacia".
  TIME_QUESTION_RE = /\b(qu[eé]\s+hora\s+(es|son|tenemos|ten[eé]s)|sab[eé]s?\s+(qu[eé]\s+)?hora\s+(es|son|ten[eé]s)|me\s+dec[ií]s?\s+(la\s+)?hora|pod[eé]s?\s+decir(me)?\s+(la\s+)?hora|ten[eé]s?\s+(la\s+)?hora|what\s+time\s+is\s+it|what'?s?\s+the\s+time)\b/i.freeze

  # Pregunta sobre el estado/lista de dispositivos. Esto antes hacía que el
  # web AI inventara informes elaborados sobre "actualizaciones de software" y
  # "sensores de humedad con problemas". Ahora respondemos desde la DB.
  DEVICES_QUERY_RE = /\b(qu[eé]\s+(dispositivos|devices)\s+tengo|c[oó]mo\s+est[aá]n?\s+(mis\s+|los\s+)?(dispositivos|devices)|list[aá]?\s+(de\s+)?(dispositivos|devices)|estado\s+de\s+(los\s+|mis\s+)?(dispositivos|devices))\b/i.freeze

  Result = Data.define(:reply, :assistant_persist)

  def self.intercept(text)
    return time_reply    if TIME_QUESTION_RE.match?(text.to_s)
    return devices_reply if DEVICES_QUERY_RE.match?(text.to_s)
    nil
  end

  # ─── Hora ─────────────────────────────────────────────────────────────────

  def self.time_reply
    tz_name    = UserTimezone.current
    now_local  = Time.now.in_time_zone(tz_name)
    formatted  = now_local.strftime("%H:%M")
    date       = now_local.strftime("%d/%m/%Y")
    display_tz = tz_name.split("/").last.tr("_", " ")  # underscores rompen Markdown de Telegram

    text = "🕐 Son las *#{formatted}* — #{date} (#{display_tz})"
    text += "\n\n_Tu zona horaria no está configurada. En Telegram usá `/zona Buenos Aires` (o tu zona)._" if tz_name == "UTC" && !timezone_explicitly_set?

    Result.new(reply: text, assistant_persist: "Son las #{formatted} (#{display_tz}).")
  end

  def self.timezone_explicitly_set?
    Setting.get(UserTimezone::SETTING_KEY).present? || ENV["MIKHAEL_TZ"].present?
  end

  # ─── Dispositivos ─────────────────────────────────────────────────────────

  def self.devices_reply
    devices = Device.order(:name)
    return Result.new(reply: "No tenés dispositivos registrados todavía.", assistant_persist: "El usuario no tiene dispositivos.") if devices.empty?

    lines = devices.map do |d|
      status      = d.online? ? "🟢 online" : "🔴 offline"
      actions     = d.actions_list.any? ? d.actions_list.join(", ") : "sin acciones definidas"
      last_seen   = d.last_seen_at ? "visto #{ActionController::Base.helpers.time_ago_in_words(d.last_seen_at)} atrás" : "nunca se conectó"
      "• *#{d.name}* (`#{d.device_id}`) — #{status}, #{last_seen}\n   _acciones:_ #{actions}"
    end

    text   = "📡 *Estado de dispositivos:*\n\n#{lines.join("\n\n")}"
    persist = "El usuario consultó por sus dispositivos. Hay #{devices.count}: #{devices.map(&:name).join(', ')}."

    Result.new(reply: text, assistant_persist: persist)
  end
end
