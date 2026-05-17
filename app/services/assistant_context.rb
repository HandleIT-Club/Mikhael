# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# System prompt unificado para el AI, compartido entre web, Telegram y CLI.
#
# Filosofía: el AI sugiere, Rails ejecuta. El prompt define los tools que
# el AI puede llamar (`call_device`, `create_reminder`), pero quien LOS
# EJECUTA es ToolCallExecutor en Ruby. El AI nunca toca DispatchAction ni
# Reminder.create directamente.
#
# Surfaces: :web, :telegram, :cli. Difieren en tono (concisión móvil para
# Telegram), no en capacidades — todas tienen los mismos tools y reglas.
#
# Composición del prompt:
#
#   [preamble editable por admin] (Setting "assistant_preamble")
#   ─────────────────────────────
#   REGLAS críticas anti-alucinación (código, NO editables)
#   Tools disponibles + JSON schema
#   Lista de dispositivos online/offline
#   Hora actual del turno (dynamic)
#
# El preamble vive en código solo como default — el admin lo personaliza
# desde /settings sin tocar nada de las reglas.
class AssistantContext
  SURFACES        = %i[web telegram cli].freeze
  PREAMBLE_KEY    = "assistant_preamble".freeze
  DEFAULT_PREAMBLE = <<~PREAMBLE.strip.freeze
    Sos Mikhael — un asistente personal. Respondé en español, de forma clara, breve y natural.
    Cuando muestres código, usá bloques markdown con el lenguaje correcto.
    El usuario es un desarrollador trabajando en macOS con Ruby on Rails.
  PREAMBLE

  def self.for(surface)
    raise ArgumentError, "surface inválida: #{surface}" unless SURFACES.include?(surface)
    new(surface)
  end

  def self.preamble
    Setting.get(PREAMBLE_KEY, DEFAULT_PREAMBLE).presence || DEFAULT_PREAMBLE
  end

  def self.set_preamble(value)
    Setting.set(PREAMBLE_KEY, value.to_s.strip)
  end

  def initialize(surface)
    @surface = surface
  end

  # Fingerprint del system prompt + primer (sin hora actual — esa va aparte).
  # Si cambia el preamble o se agregan devices, se invalida y las
  # conversaciones cacheadas (Telegram) se resetean.
  def fingerprint
    Digest::SHA256.hexdigest(static_prompt + primer.to_json)
  end

  def build(memories: [])
    base = "#{static_prompt}\n\n#{dynamic_prompt}"
    memories.any? ? "#{base}\n\n#{memories_section(memories)}" : base
  end

  def primer
    devices    = Device.order(:name)
    sample_id  = devices.first&.device_id || "esp32_riego"
    second_id  = devices.second&.device_id || sample_id

    summary =
      if devices.empty?
        "no tenés ningún dispositivo registrado"
      else
        names = devices.map { |d| "*#{d.name}* (`#{d.device_id}`)" }
        "tenés #{devices.count} dispositivo#{devices.count == 1 ? '' : 's'}: #{names.join(' y ')}"
      end

    # NO incluimos un ejemplo de create_reminder acá — una fecha hardcodeada
    # ancla al modelo a ese mes/año (visto en producción: el primer con
    # "2026-01-15" hizo devolver enero estando en mayo). Los ejemplos de
    # create_reminder solo viven en el static_prompt.
    [
      { role: "user",      content: "Hola Mikhael, ¿qué dispositivos tengo?" },
      { role: "assistant", content: "¡Hola! Soy Mikhael. Sí, #{summary}. Decime qué hacer con ellos." },
      { role: "user",      content: "activá #{sample_id}" },
      { role: "assistant", content: %({"tool":"call_device","device_id":"#{sample_id}","context":"el usuario pide activar el dispositivo"}) },
      { role: "user",      content: "iniciá el otro dispositivo" },
      { role: "assistant", content: %({"tool":"call_device","device_id":"#{second_id}","context":"el usuario pide iniciar el dispositivo"}) },
      { role: "user",      content: "gracias" },
      { role: "assistant", content: "¡De nada! Cualquier cosa avisame." }
    ]
  end

  def static_prompt
    <<~PROMPT
      #{self.class.preamble}

      REGLAS (no negociables):
      - NUNCA inventes el estado de un dispositivo, ni digas que "actualizaste software", "detectaste un sensor con problemas", "el riego se está ejecutando", etc. Vos NO sabés el estado real — solo Rails lo sabe. Si te preguntan por el estado, respondé con lo que aparece en "Dispositivos del usuario" abajo (online/offline + acciones disponibles), nada más.
      - NUNCA digas "soy un modelo de lenguaje" o "no tengo acceso a tus dispositivos". Es FALSO. La lista real está abajo.
      - NUNCA digas "no tengo acceso a información en tiempo real" ni "no sé qué hora es". Es FALSO: la fecha y hora actuales te llegan en cada turno bajo "FECHA Y HORA ACTUAL". Usalas para responder preguntas de hora/fecha en la zona horaria del usuario.
      - NUNCA simules ejecutar acciones ni digas "activé el riego". Para EJECUTAR algo tenés que llamar al tool `call_device`. Si no llamás al tool, NO PASA NADA.
      - NUNCA simules programar recordatorios. Para programar uno tenés que llamar al tool `create_reminder`. Si no lo llamás, NO PASA NADA.
      - Cuando uses una herramienta, respondé SOLO con el JSON. Nada antes, nada después. Cero prosa, cero markdown.
      - Para charla, preguntas o saludos: respondé en lenguaje natural normal.
      #{concision_rule}

      #{devices_section}

      HERRAMIENTAS DISPONIBLES — Rails las ejecuta cuando vos las invocás. Sin invocación no pasa nada:

      1) Comandar un dispositivo AHORA:
      {"tool":"call_device","device_id":"<id_string>","context":"<qué pedirle>"}

      2) Programar un recordatorio o acción para el futuro:
      {"tool":"create_reminder","scheduled_for":"<ISO8601 UTC real>","message":"<texto>","kind":"notify"|"query_device","device_id":"<id_string>"|null}

      Reglas para create_reminder:
      - scheduled_for: DEBE ser un timestamp ISO8601 REAL calculado sumando minutos/horas/días a la "FECHA Y HORA ACTUAL" del turno actual.
        Formato exacto: "YYYY-MM-DDTHH:MM:SSZ" — con la Z al final, sin offset, sin milisegundos.
        EJEMPLO: si ahora son las 2026-05-15 22:00:00 UTC y el usuario dice "en 5 minutos" → "2026-05-15T22:05:00Z"
        NUNCA pongas texto descriptivo, lenguaje natural ni placeholders. Solo el timestamp computado.
      - kind="notify" → aviso simple
      - kind="query_device" → en ese momento se va a consultar/comandar al dispositivo
      - device_id: el id_string del dispositivo si kind=query_device, sino null

      EJEMPLOS:
        Usuario: "iniciá el riego"
        Vos:     {"tool":"call_device","device_id":"esp32_riego","context":"el usuario quiere iniciar el riego"}

        Usuario: "recordame en 2 minutos de irme a dormir"  (asumiendo ahora 2026-05-15 22:00:00 UTC)
        Vos:     {"tool":"create_reminder","scheduled_for":"2026-05-15T22:02:00Z","message":"irse a dormir","kind":"notify","device_id":null}

        Usuario: "mañana a las 8 preguntale al riego cómo está"  (asumiendo ahora 2026-05-15 22:00:00 UTC, zona -03)
        Vos:     {"tool":"create_reminder","scheduled_for":"2026-05-16T11:00:00Z","message":"cómo está el riego","kind":"query_device","device_id":"esp32_riego"}

        Usuario: "qué dispositivos tengo"
        Vos:     Tenés ESP32 Riego y ESP32 Cerradura.

        Usuario: "hola"
        Vos:     ¡Hola! ¿En qué te ayudo?
    PROMPT
  end

  # Hora actual, fresca cada turno. NO entra en el fingerprint.
  def dynamic_prompt
    tz_name   = UserTimezone.current
    now_utc   = Time.now.utc
    now_local = now_utc.in_time_zone(tz_name)

    <<~PROMPT.chomp
      <hechos_del_turno_actual>
        <hora_local>#{now_local.strftime('%Y-%m-%d %H:%M:%S')}</hora_local>
        <hora_utc>#{now_utc.strftime('%Y-%m-%d %H:%M:%S')}</hora_utc>
        <zona_horaria>#{tz_name}</zona_horaria>
      </hechos_del_turno_actual>

      Cuando hables en lenguaje natural, usá la hora_local.
      Cuando computes scheduled_for en create_reminder, usá la hora_utc en formato ISO8601 con Z al final.
    PROMPT
  end

  def devices_section
    devices = Device.order(:name)
    return "El usuario aún no tiene dispositivos registrados." if devices.empty?

    lines = devices.map do |d|
      status  = d.online? ? "🟢 online" : "🔴 offline"
      actions = d.actions_list.any? ? d.actions_list.join(", ") : "(sin acciones definidas)"
      "- `#{d.device_id}` (#{d.name}, #{status}, seguridad #{d.security_level}): #{actions}"
    end
    "Dispositivos del usuario:\n#{lines.join("\n")}"
  end

  private

  def concision_rule
    case @surface
    when :telegram then "- Sos conciso (chat móvil): respuestas cortas y naturales, máximo 2-3 líneas para charla, 1 sola línea de confirmación tras un tool."
    when :web      then "- Sos directo y conciso. Evitá listas con bullets, secciones largas o tipo \"informe\". Respondé como en un chat real."
    when :cli      then "- Sos preciso y directo. Salida pensada para terminal: párrafos cortos, código en bloques."
    end
  end

  def memories_section(memories)
    lines = memories.map { |m| "- #{m.summary}" }
    "Conversaciones anteriores relevantes:\n#{lines.join("\n")}"
  end
end
