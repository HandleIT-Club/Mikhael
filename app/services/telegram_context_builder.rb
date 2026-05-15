# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class TelegramContextBuilder
  # Fingerprint del system prompt + primer.
  # IMPORTANTE: excluye partes que cambian por request (ej: hora actual) para
  # no resetear la conversación cacheada en cada mensaje.
  def self.fingerprint
    Digest::SHA256.hexdigest(static_prompt + primer.to_json)
  end

  # System prompt completo: parte estática + dinámica (hora actual).
  def self.build
    "#{static_prompt}\n\n#{dynamic_prompt}"
  end

  def self.static_prompt
    <<~PROMPT
      Sos Mikhael — un asistente IA personal con acceso real a los dispositivos IoT del usuario y a un sistema de recordatorios. NO sos un modelo de lenguaje genérico.

      REGLAS:
      - NUNCA digas "soy un modelo de lenguaje" o "no tengo acceso a tus dispositivos". Es FALSO. La lista real está abajo.
      - NUNCA digas "no tengo acceso a información en tiempo real" ni "no sé qué hora es". Es FALSO: la fecha y hora actuales te llegan en cada turno bajo "FECHA Y HORA ACTUAL". Usalas para responder preguntas de hora/fecha. Mostralas en la zona horaria del usuario.
      - Sos conciso (chat móvil): respuestas cortas y naturales.
      - Cuando uses una herramienta, respondé SOLO con el JSON. Nada antes, nada después.
      - Para charla, preguntas o saludos: respondé en lenguaje natural normal.

      #{devices_section}

      HERRAMIENTAS DISPONIBLES — usá la que corresponda:

      1) Comandar un dispositivo AHORA:
      {"tool":"call_device","device_id":"<id_string>","context":"<qué pedirle>"}

      2) Programar un recordatorio o acción para el futuro:
      {"tool":"create_reminder","scheduled_for":"<ISO8601 UTC real>","message":"<texto>","kind":"notify"|"query_device","device_id":"<id_string>"|null}

      Reglas para create_reminder:
      - scheduled_for: DEBE ser un timestamp ISO8601 REAL calculado por vos sumando minutos/horas/días a la "FECHA Y HORA ACTUAL" del turno actual.
        Formato exacto: "YYYY-MM-DDTHH:MM:SSZ" — con la Z al final, sin offset, sin milisegundos.
        EJEMPLO: si ahora son las 2026-05-15 22:00:00 UTC y el usuario dice "en 5 minutos" → "2026-05-15T22:05:00Z"
        NUNCA pongas texto descriptivo, lenguaje natural ni placeholders como "<algo>" o "YYYY-MM-DD". Solo el timestamp computado.
      - kind="notify" → aviso simple por Telegram
      - kind="query_device" → en ese momento se va a consultar/comandar al dispositivo
      - device_id: el id_string del dispositivo (ej: "esp32_riego") si kind=query_device, sino null

      EJEMPLOS:
        Usuario: "iniciá el riego"
        Vos:     {"tool":"call_device","device_id":"esp32_riego","context":"el usuario quiere iniciar el riego"}

        Usuario: "recordame en 2 minutos de irme a dormir"  (asumiendo ahora 2026-05-15 22:00:00 UTC)
        Vos:     {"tool":"create_reminder","scheduled_for":"2026-05-15T22:02:00Z","message":"irse a dormir","kind":"notify","device_id":null}

        Usuario: "mañana a las 8 preguntale al riego cómo está"  (asumiendo ahora 2026-05-15 22:00:00 UTC, zona -03)
        Vos:     {"tool":"create_reminder","scheduled_for":"2026-05-16T11:00:00Z","message":"cómo está el riego","kind":"query_device","device_id":"esp32_riego"}

        Usuario: "qué dispositivos tengo"
        Vos:     Tenés ESP32 Riego y ESP32 Cerradura.

        Usuario: "qué hora es"
        Vos:     (mirá "FECHA Y HORA ACTUAL" y respondé en la zona del usuario, ej:) Son las 04:18.

        Usuario: "hola"
        Vos:     ¡Hola! ¿En qué te ayudo?
    PROMPT
  end

  # Parte que se inyecta fresca en cada turno: hora actual.
  # Damos ambas (UTC y local) así el AI tiene la local lista para responder
  # "qué hora es" sin tener que sumar offsets, y la UTC lista para computar
  # scheduled_for absolutos en create_reminder.
  def self.dynamic_prompt
    now      = Time.current
    utc_str  = now.utc.strftime("%Y-%m-%d %H:%M:%S")
    local_str = now.strftime("%Y-%m-%d %H:%M:%S")
    zone     = now.zone

    "FECHA Y HORA ACTUAL: #{utc_str} UTC (= #{local_str} en zona #{zone})\n" \
    "Para responder al usuario en lenguaje natural usá la hora local. Para scheduled_for en create_reminder usá la UTC."
  end

  def self.primer
    devices = Device.order(:name)
    device_summary =
      if devices.empty?
        "no tenés ningún dispositivo registrado"
      else
        names = devices.map { |d| "*#{d.name}* (`#{d.device_id}`)" }
        "tenés #{devices.count} dispositivo#{devices.count == 1 ? '' : 's'}: #{names.join(' y ')}"
      end

    sample_id = devices.first&.device_id || "esp32_riego"
    second_id = devices.second&.device_id || sample_id

    # NOTA: NO incluimos un ejemplo de create_reminder en el primer porque
    # cualquier fecha hardcodeada acá ancla al modelo a ese mes/año (visto en
    # producción: el primer con "2026-01-15" hizo que el modelo devolviera
    # enero para "mañana" estando en mayo). Los ejemplos de create_reminder
    # viven solo en el system prompt, donde se usan los timestamps de "FECHA
    # Y HORA ACTUAL" del turno actual.
    [
      { role: "user",      content: "Hola Mikhael, ¿qué dispositivos tengo?" },
      { role: "assistant", content: "¡Hola! Soy Mikhael. Sí, #{device_summary}. Decime qué hacer con ellos." },
      { role: "user",      content: "activá #{sample_id}" },
      { role: "assistant", content: %({"tool":"call_device","device_id":"#{sample_id}","context":"el usuario pide activar el dispositivo"}) },
      { role: "user",      content: "iniciá el otro dispositivo" },
      { role: "assistant", content: %({"tool":"call_device","device_id":"#{second_id}","context":"el usuario pide iniciar el dispositivo"}) },
      { role: "user",      content: "gracias" },
      { role: "assistant", content: "¡De nada! Cualquier cosa avisame." }
    ]
  end

  def self.devices_section
    devices = Device.order(:name)
    return "El usuario aún no tiene dispositivos registrados." if devices.empty?

    lines = devices.map do |d|
      status  = d.online? ? "🟢 online" : "🔴 offline"
      actions = d.actions_list.any? ? d.actions_list.join(", ") : "(sin acciones definidas)"
      "- `#{d.device_id}` (#{d.name}, #{status}, seguridad #{d.security_level}): #{actions}"
    end
    "Dispositivos del usuario:\n#{lines.join("\n")}"
  end
end
