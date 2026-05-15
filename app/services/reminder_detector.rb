# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Usa el AI para detectar si un mensaje de Telegram es un pedido de recordatorio
# o acción diferida. Devuelve un Hash con la intención parseada.
#
# Retorna:
#   Success({ "is_reminder" => false })
#   Success({ "is_reminder" => true, "scheduled_for" => Time, "message" => String,
#             "kind" => "notify"|"query_device", "device_id" => Integer|nil })
#   Success({ "is_reminder" => false, "needs_clarification" => true })
#   Failure(:no_model | :ai_error | :invalid_json)
class ReminderDetector
  include Dry::Monads[:result]

  SYSTEM_PROMPT = <<~PROMPT.freeze
    Sos un clasificador de intenciones. Respondé ÚNICAMENTE con JSON puro. Sin texto antes ni después, sin bloques markdown, sin explicaciones.

    FECHA Y HORA ACTUAL (usá este valor para calcular tiempos relativos): %<now>s UTC
    Zona horaria: %<timezone>s
    Dispositivos disponibles: %<devices>s

    TAREA: Determiná si el mensaje del usuario es un pedido de recordatorio o acción diferida.

    SCHEMA DE RESPUESTA — elegí exactamente una opción:

    Opción A — es un recordatorio con hora clara:
    {"is_reminder":true,"scheduled_for":"YYYY-MM-DDTHH:MM:SSZ","message":"texto","kind":"notify","device_id":null}

    Opción B — es un recordatorio pero faltan datos para entender el momento exacto:
    {"is_reminder":false,"needs_clarification":true}

    Opción C — NO es un recordatorio:
    {"is_reminder":false}

    REGLAS para calcular scheduled_for (siempre en UTC, siempre ISO8601 completo):
    - "en 2 minutos" → %<now>s + 2 minutos, en UTC
    - "en 2 horas" → %<now>s + 2 horas, en UTC
    - "mañana a las 8" → fecha de mañana a las 08:00 hora local (%<timezone>s), convertida a UTC
    - "el viernes" → próximo viernes a las 09:00 hora local, convertida a UTC
    - "a las 10" sin fecha → hoy a las 10:00; si ya pasó, mañana a las 10:00

    REGLAS para kind:
    - "query_device" si menciona consultar, revisar, preguntar o comandar un dispositivo
    - "notify" para el resto (avisos simples)
    - device_id es el id numérico entero del dispositivo; null si kind="notify"

    EJEMPLOS CONCRETOS (asumiendo que ahora son las 2026-05-15 22:00:00 UTC):
    "Recordame en 2 minutos" → {"is_reminder":true,"scheduled_for":"2026-05-15T22:02:00Z","message":"recordatorio","kind":"notify","device_id":null}
    "Recordame en 2 horas revisar el riego" → {"is_reminder":true,"scheduled_for":"2026-05-16T00:00:00Z","message":"revisar el riego","kind":"notify","device_id":null}
    "Mañana a las 8 preguntale al ESP32 del riego cómo está" → {"is_reminder":true,"scheduled_for":"2026-05-16T11:00:00Z","message":"cómo está el riego","kind":"query_device","device_id":1}
    "Qué hora es" → {"is_reminder":false}
    "Avisame el lunes" → {"is_reminder":false,"needs_clarification":true}
  PROMPT

  def call(text)
    model = ModelSelector.first_available
    return Failure(:no_model) unless model

    provider = Conversation.all_models[model]
    client   = Ai::Dispatcher.for(provider)

    system_msg = build_system_prompt
    result = client.chat(
      messages: [
        { role: "system", content: system_msg },
        { role: "user",   content: text }
      ],
      model: model
    )

    return Failure(:ai_error) if result.failure?

    parse_response(result.value!.content)
  end

  private

  def build_system_prompt
    devices = Device.all.map { |d| { id: d.id, name: d.name, device_id: d.device_id } }
    now     = Time.current.utc.strftime("%Y-%m-%d %H:%M:%S")

    format(
      SYSTEM_PROMPT,
      now:      now,
      timezone: Time.current.zone.to_s,
      devices:  devices.to_json
    )
  end

  def parse_response(content)
    cleaned = content.to_s.strip.gsub(/\A```(?:json)?\s*|\s*```\z/m, "")

    # Intentamos parsear el texto limpio directamente; si tiene texto extra,
    # extraemos el primer objeto JSON válido escaneando desde cada '{'.
    data = extract_json(cleaned)
    return Failure(:invalid_json) unless data&.key?("is_reminder")

    Rails.logger.debug("ReminderDetector: raw=#{data.inspect}")

    # Convertir scheduled_for a Time — si el AI devolvió algo no parseable,
    # lo tratamos como "necesita aclaración" en vez de caer al chat.
    if data["is_reminder"] && data["scheduled_for"].present?
      parsed_time = parse_time(data["scheduled_for"].to_s)

      if parsed_time.nil?
        Rails.logger.warn("ReminderDetector: scheduled_for inparseable=#{data['scheduled_for'].inspect}")
        return Success({ "is_reminder" => false, "needs_clarification" => true })
      end

      data["scheduled_for"] = parsed_time
    end

    Success(data)
  end

  # Intenta parsear JSON puro; si falla, busca el primer objeto JSON válido en el texto.
  def extract_json(text)
    return JSON.parse(text) rescue nil if text.start_with?("{")

    # Escanear posiciones de '{' y probar desde cada una
    pos = 0
    while (idx = text.index("{", pos))
      candidate = text[idx..]
      # Intenta el substring completo desde idx
      begin
        return JSON.parse(candidate)
      rescue JSON::ParserError
        # El substring no es JSON completo; probamos acotar al primer par balanceado.
        balanced = first_balanced_json(candidate)
        return JSON.parse(balanced) if balanced
        pos = idx + 1
      end
    end

    nil
  end

  # Extrae la subcadena balanceada en llaves más corta desde el inicio del texto.
  def first_balanced_json(text)
    depth = 0
    in_string = false
    escape_next = false

    text.each_char.with_index do |ch, i|
      if escape_next
        escape_next = false
        next
      end
      if ch == "\\" && in_string
        escape_next = true
        next
      end
      in_string = !in_string if ch == '"'
      next if in_string

      depth += 1 if ch == "{"
      depth -= 1 if ch == "}"

      return text[0..i] if depth.zero? && i.positive?
    end

    nil
  end

  def parse_time(str)
    Time.zone.parse(str)
  rescue ArgumentError, TypeError
    nil
  end
end
