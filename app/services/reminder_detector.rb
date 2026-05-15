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
    Sos un analizador de intenciones para un asistente personal de IoT.
    Tu única tarea es detectar si el mensaje es un pedido de recordatorio o acción diferida.

    Fecha y hora actual: %<now>s
    Zona horaria del servidor: %<timezone>s
    Dispositivos disponibles (id numérico, nombre, device_id): %<devices>s

    Respondé ÚNICAMENTE con JSON válido, sin texto adicional, sin bloques markdown.

    Si es un recordatorio:
    {"is_reminder": true, "scheduled_for": "<ISO8601 en UTC>", "message": "<texto del recordatorio>", "kind": "notify"|"query_device", "device_id": <número>|null}

    Si NO podés determinar la hora (ambigua o faltante):
    {"is_reminder": false, "needs_clarification": true}

    Si NO es un recordatorio:
    {"is_reminder": false}

    Reglas de parsing de tiempo:
    - "en X horas/minutos" → fecha relativa a la hora actual
    - "mañana a las X" → mañana a esa hora (asumí 24h si no se especifica AM/PM)
    - "el lunes/martes/..." → próximo día de esa semana a las 09:00
    - "a las X" sin fecha → hoy a esa hora; si ya pasó, mañana a esa hora

    Reglas de kind:
    - kind="query_device" si el mensaje menciona consultar, revisar o comandar un dispositivo
    - kind="notify" para todo lo demás (recordatorios simples, avisos, etc.)
    - device_id es el id numérico de la lista; null si kind="notify"

    Ejemplos:
    "Recordame en 2 horas revisar el riego" → is_reminder:true, kind:"notify"
    "Mañana a las 8 preguntale al ESP32 del riego cómo está" → is_reminder:true, kind:"query_device", device_id:<id del dispositivo de riego>
    "Cuál es la capital de Francia" → is_reminder:false
    "Avisame el lunes" → is_reminder:false, needs_clarification:true (falta aclarar qué)
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

    format(
      SYSTEM_PROMPT,
      now:      Time.current.strftime("%Y-%m-%d %H:%M:%S"),
      timezone: Time.current.zone.to_s,
      devices:  devices.to_json
    )
  end

  def parse_response(content)
    cleaned = content.to_s.strip.gsub(/\A```(?:json)?\s*|\s*```\z/m, "")
    match   = cleaned.match(/\{.*\}/m)
    return Failure(:invalid_json) unless match

    data = JSON.parse(match[0])
    return Failure(:invalid_json) unless data.key?("is_reminder")

    # Convertir scheduled_for string a Time si está presente
    if data["is_reminder"] && data["scheduled_for"].present?
      data["scheduled_for"] = Time.zone.parse(data["scheduled_for"])
    end

    Success(data)
  rescue JSON::ParserError
    Failure(:invalid_json)
  end
end
