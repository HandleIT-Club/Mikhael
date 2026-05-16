# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Toma una respuesta del AI, intenta parsearla como tool call, y si lo es
# ejecuta la acción real en Rails. Si no es tool call, devuelve nil y el
# caller usa la respuesta original del AI.
#
# Centraliza la lógica que antes estaba duplicada/ausente:
#   - Telegram tenía call_device y create_reminder en TelegramMessageHandler
#   - Web no tenía nada — el AI alucinaba "activé el riego" sin ejecutar nada
#
# Filosofía: el AI sugiere, Rails ejecuta. Este service es el "ejecuta".
#
# Si el AI no llama al tool pero el usuario claramente pidió un recordatorio
# (regex), creamos el Reminder igual (fallback determinístico). Cubre el caso
# en producción donde el modelo se "rinde" tras varios fallos y responde
# chat text inventado.
class ToolCallExecutor
  include Dry::Monads[:result]

  Result = Data.define(:reply, :assistant_persist) do
    def self.message(text)
      new(reply: text, assistant_persist: text)
    end

    def self.dual(reply:, persist:)
      new(reply: reply, assistant_persist: persist)
    end
  end

  # Coincide con "recordame X en N min", "podrías recordarme...", "que me
  # recuerdes...", etc. Cubre vos/tú/infinitivo/subjuntivo.
  REMINDER_INTENT_RE = /
    \b(
      record(a|á|ás|ar)me |
      recu[ée]rda?me |
      record(a|á|ás|ar)nos |
      que\s+me\s+(record(a|á|e|es|aras)|recuerd(a|e|es)) |
      av[ií]s(a|á|ame|arme|en) |
      avisame |
      pod(é|e)s\s+record(a|á|ar)me |
      podr[ií]as?\s+record(a|á|ar)me |
      necesito\s+que\s+me\s+(recuerd|record)
    )\b
  /xi.freeze

  # Recibe el user explícito porque este service corre tanto desde
  # MessagesController (con Current.user) como desde el TelegramPollJob (donde
  # Current.user no está seteado — lo resolvemos por chat_id en el handler).
  def initialize(user_message:, user:, surface: :web)
    @user_message = user_message.to_s
    @user         = user
    @surface      = surface
  end

  # Devuelve un Result o nil.
  # nil = "esta respuesta no es un tool call ni intent de recordatorio";
  # el caller muestra la respuesta original del AI.
  def call(ai_response_content)
    tool = ToolCallParser.parse(ai_response_content.to_s)

    if tool && tool["tool"] == "create_reminder"
      return execute_create_reminder(tool)
    end

    if tool && (tool["tool"] == "call_device" || tool["device_id"].present?)
      return execute_call_device(tool)
    end

    # Red de seguridad: el AI a veces se rinde del tool y responde chat text
    # inventado. Si el mensaje del usuario era claramente un recordatorio, lo
    # hacemos nosotros.
    if reminder_intent?(@user_message)
      Rails.logger.warn("ToolCallExecutor: AI omitió tool create_reminder pero el user pidió uno: #{@user_message.inspect}. Fallback manual.")
      return create_reminder_from_user_message
    end

    nil
  end

  def reminder_intent?(text)
    REMINDER_INTENT_RE.match?(text.to_s)
  end

  private

  def execute_call_device(tool)
    device_id   = tool["device_id"]
    device      = Device.find_by(device_id: device_id)
    ai_context  = tool["context"] || tool["message"]

    return Result.message("❌ Dispositivo `#{device_id}` no encontrado.") unless device

    full_context = [
      %(Mensaje literal del usuario: "#{@user_message}"),
      ai_context.present? ? "Interpretación previa: #{ai_context}" : nil
    ].compact.join("\n")

    result = DispatchAction.new.call(device: device, context: full_context, trusted: true)
    result.either(
      ->(response) {
        MqttPublisher.publish(device, response)
        Result.message(format_device_reply(device, response))
      },
      ->(_) { Result.message("❌ No se pudo comandar #{device.name}.") }
    )
  end

  def format_device_reply(device, response)
    msg  = "✅ *#{device.name}* → `#{response[:action]}`"
    msg += "\nValor: #{response[:value]}" if response[:value]
    msg += "\n_#{response[:reason]}_"
    msg += "\n⚠️ _Alta seguridad — requiere confirmación física._" if response[:requires_confirmation]
    msg
  end

  def execute_create_reminder(tool)
    Rails.logger.info("create_reminder tool call: #{tool.inspect}, user_msg=#{@user_message.inspect}")

    raw_time      = tool["scheduled_for"].to_s
    scheduled_for = parse_iso8601(raw_time)

    # Si el AI alucinó una fecha en el pasado o ilegible, la fuente de verdad
    # es el mensaje original del usuario.
    if scheduled_for.nil? || scheduled_for <= Time.current
      fallback = parse_relative(raw_time, tool["message"].to_s, @user_message)
      scheduled_for = fallback if fallback
    end

    return Result.message(time_unreadable_reply(raw_time)) if scheduled_for.nil?
    return Result.message("❌ La hora del recordatorio ya pasó. Probá con un momento futuro.") if scheduled_for <= Time.current

    fk_id = resolve_device_id(tool)
    if fk_id == :missing
      raw = tool["device_id"].to_s.presence || "<vacío>"
      return Result.message("❌ No encontré el dispositivo `#{raw}` para programar el recordatorio.")
    end

    persist_reminder(
      scheduled_for: scheduled_for,
      message:       tool["message"].to_s.presence || "recordatorio",
      kind:          tool["kind"].to_s.presence || "notify",
      device_id:     fk_id
    )
  end

  def create_reminder_from_user_message
    scheduled_for = parse_relative(@user_message)
    return Result.message("❌ Entendí que querés un recordatorio pero no pude entender cuándo. Probá con \"en X minutos/horas\" o \"mañana a las 8\".") if scheduled_for.nil?

    persist_reminder(
      scheduled_for: scheduled_for,
      message:       extract_reminder_text(@user_message),
      kind:          "notify",
      device_id:     nil
    )
  end

  # Devuelve :missing si kind=query_device pero el device_id es nulo/desconocido.
  # Devuelve nil para kind=notify (sin device).
  # Devuelve el FK integer si todo OK.
  def resolve_device_id(tool)
    return nil unless tool["kind"].to_s == "query_device"
    raw = tool["device_id"].to_s
    return :missing if raw.blank?

    device = Device.find_by(device_id: raw) || Device.find_by(id: raw.to_i)
    device ? device.id : :missing
  end

  def persist_reminder(scheduled_for:, message:, kind:, device_id:)
    if (existing = recent_duplicate(message, scheduled_for))
      Rails.logger.info("persist_reminder: duplicado de Reminder ##{existing.id} — silencioso")
      return nil  # silencio total — el primer mensaje ya fue
    end

    reminder = @user.reminders.new(scheduled_for: scheduled_for, message: message, kind: kind, device_id: device_id)

    if reminder.save
      ExecuteReminderJob.set(wait_until: reminder.scheduled_for).perform_later(reminder.id)
      Result.dual(reply: format_reminder_reply(reminder), persist: format_reminder_persist(reminder))
    else
      Rails.logger.error("persist_reminder: #{reminder.errors.full_messages.join(', ')}")
      Result.message("❌ No pude programar el recordatorio: #{reminder.errors.full_messages.join(', ')}")
    end
  end

  def format_reminder_reply(reminder)
    formatted = reminder.scheduled_for.in_time_zone(UserTimezone.current).strftime("%d/%m a las %H:%M")
    "⏰ Recordatorio ##{reminder.id} programado para el *#{formatted}*:\n_#{reminder.message}_"
  end

  def format_reminder_persist(reminder)
    formatted = reminder.scheduled_for.in_time_zone(UserTimezone.current).strftime("%d/%m a las %H:%M")
    "Recordatorio ##{reminder.id} programado para el #{formatted}: #{reminder.message}"
  end

  # Dedup scoped al user — dos users con el mismo recordatorio no se pisan.
  def recent_duplicate(message, scheduled_for)
    @user.reminders.where(message: message, executed_at: nil)
                   .where("scheduled_for BETWEEN ? AND ?", scheduled_for - 1.minute, scheduled_for + 1.minute)
                   .where("created_at > ?", 30.seconds.ago)
                   .first
  end

  def time_unreadable_reply(raw)
    "❌ No pude programar el recordatorio: no entendí la hora «#{raw}». Probá con \"en 5 minutos\", \"mañana a las 8\", etc."
  end

  def parse_iso8601(str)
    return nil if str.blank?
    return nil if str.include?("<") || str.include?(">")
    return nil if str.match?(/\b(YYYY|MM|DD|HH|SS)\b/)
    return nil unless str.match?(/\A\d{4}-\d{2}-\d{2}/)
    Time.zone.parse(str)
  rescue ArgumentError, TypeError, Date::Error
    nil
  end

  # Captura "<número> <unidad>" en cualquier parte del string. Acepta español
  # e inglés. Recorre varios strings hasta encontrar un match.
  def parse_relative(*strings)
    strings.each do |str|
      next if str.blank?
      next unless (m = str.match(/(\d+)\s*([a-zA-Záéíóú]+)/))

      n          = m[1].to_i
      multiplier = unit_to_seconds(m[2].downcase)
      return (n * multiplier).seconds.from_now if multiplier
    end
    nil
  end

  def unit_to_seconds(unit)
    case unit
    when "minuto", "minutos", "min", "mins", "minute", "minutes"          then 60
    when "hora", "horas", "h", "hr", "hrs", "hs", "hour", "hours"         then 3600
    when "día", "días", "dia", "dias", "day", "days", "d"                 then 86_400
    end
  end

  def extract_reminder_text(message)
    text = message.to_s.dup
    text.sub!(REMINDER_INTENT_RE, "")
    text.sub!(/\A\s*(de|que|a)\s+/i, "")
    text.sub!(/\s*en\s+\d+\s*[a-zA-Záéíóú]+\s*/i, " ")
    text.strip.presence || "recordatorio"
  end
end
