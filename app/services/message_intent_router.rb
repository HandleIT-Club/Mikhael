# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Intercepta mensajes que tienen una respuesta determinística desde Rails,
# antes de que lleguen al AI. Esto evita las alucinaciones típicas del modelo
# para preguntas que TIENEN respuesta exacta (hora, fecha, etc.) — la regla
# es: si Rails tiene el dato, lo respondemos desde Rails, no desde el AI.
#
# Devuelve nil si no hay intercepción (el caller sigue al AI).
# Devuelve un String si interceptó (el caller usa ese string como respuesta).
#
# Compartido entre TelegramMessageHandler (Telegram) y MessagesController (web)
# para que el comportamiento sea uniforme entre superficies.
class MessageIntentRouter
  # Pregunta de hora — exige que después de "hora" venga un verbo de existencia
  # (es/son/tenemos/tenés) para evitar falsos positivos como "qué hora cierra la
  # farmacia". Cubre las variantes argentinas comunes:
  #   "qué hora es", "qué hora son", "qué hora tenemos", "qué hora tenés"
  #   "sabés qué hora es", "podés decirme la hora", "me decís la hora", "tenés hora"
  #   "what time is it"
  TIME_QUESTION_RE = /\b(qu[eé]\s+hora\s+(es|son|tenemos|ten[eé]s)|sab[eé]s?\s+(qu[eé]\s+)?hora\s+(es|son|ten[eé]s)|me\s+dec[ií]s?\s+(la\s+)?hora|pod[eé]s?\s+decir(me)?\s+(la\s+)?hora|ten[eé]s?\s+(la\s+)?hora|what\s+time\s+is\s+it|what'?s?\s+the\s+time)\b/i.freeze

  Result = Data.define(:reply, :assistant_persist)

  def self.intercept(text)
    return time_reply if TIME_QUESTION_RE.match?(text.to_s)
    nil
  end

  def self.time_reply
    tz_name    = UserTimezone.current
    now_local  = Time.now.in_time_zone(tz_name)
    formatted  = now_local.strftime("%H:%M")
    date       = now_local.strftime("%d/%m/%Y")

    # IANA names tienen "/" y "_" (ej "America/Argentina/Buenos_Aires"). El "_"
    # rompe el parser de Markdown de Telegram (lo interpreta como itálica) y la
    # API rechaza el mensaje. Mostramos solo la última parte con underscores
    # convertidos a espacios. "America/Argentina/Buenos_Aires" → "Buenos Aires".
    display_tz = tz_name.split("/").last.tr("_", " ")

    text = "🕐 Son las *#{formatted}* — #{date} (#{display_tz})"
    text += "\n\n_Tu zona horaria no está configurada. En Telegram usá `/zona Buenos Aires` (o tu zona)._" if tz_name == "UTC" && !timezone_explicitly_set?

    Result.new(reply: text, assistant_persist: "Son las #{formatted} (#{display_tz}).")
  end

  def self.timezone_explicitly_set?
    Setting.get(UserTimezone::SETTING_KEY).present? || ENV["MIKHAEL_TZ"].present?
  end
end
