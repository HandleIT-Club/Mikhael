# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class TelegramMessageHandler
  CONV_CACHE_KEY = "telegram_conversation_id".freeze

  def call(text)
    case text.strip
    when "/start"
      TelegramClient.send_message(
        "👋 Soy *Mikhael*. Sé qué dispositivos tenés, los puedo comandar y puedo programarte recordatorios.\n\n" \
        "Comandos:\n" \
        "`/dispositivos` — listar devices\n" \
        "`/recordatorios` — ver recordatorios pendientes\n" \
        "`/borrar_recordatorio <id>` — cancelar un recordatorio\n" \
        "`/reset` — empezar de cero"
      )
    when "/dispositivos"
      list_devices
    when "/recordatorios"
      list_reminders
    when /\A\/borrar_recordatorio\s+(\d+)\z/
      delete_reminder(Regexp.last_match(1).to_i)
    when "/reset"
      reset_conversation
      TelegramClient.send_message("✅ Conversación reiniciada.")
    else
      handle_chat(text)
    end
  end

  private

  def handle_chat(text)
    conversation = find_or_create_conversation
    return TelegramClient.send_message("❌ No hay modelos disponibles.") unless conversation

    result = CreateMessage.new.call(
      conversation:  conversation,
      content:       text,
      system_prompt: TelegramContextBuilder.build,
      primer:        TelegramContextBuilder.primer
    )

    result.either(
      ->(response) { handle_ai_response(response, text) },
      ->(error)    { TelegramClient.send_message("❌ Error: #{error}") }
    )
  end

  # Despacha sobre el tool elegido por el AI. Una sola llamada al modelo;
  # los recordatorios y los comandos a dispositivos viven en el mismo system prompt.
  def handle_ai_response(response, user_message)
    tool_call = ToolCallParser.parse(response.content)

    if tool_call && tool_call["tool"] == "create_reminder"
      return TelegramClient.send_message(create_reminder_from_tool(tool_call))
    end

    if tool_call && (tool_call["device_id"].present? || tool_call["tool"] == "call_device")
      ai_context = tool_call["context"] || tool_call["message"]
      summary    = invoke_device(tool_call["device_id"], ai_context, user_message)
      return TelegramClient.send_message(summary)
    end

    TelegramClient.send_message(response.content)
  end

  def create_reminder_from_tool(tool)
    Rails.logger.info("create_reminder tool call: #{tool.inspect}")

    raw_time      = tool["scheduled_for"].to_s
    scheduled_for = parse_iso8601(raw_time) || parse_relative(raw_time, tool["message"].to_s)

    if scheduled_for.nil?
      Rails.logger.warn("create_reminder: no pude parsear scheduled_for=#{raw_time.inspect}")
      return "❌ No pude programar el recordatorio: no entendí la hora «#{raw_time}». Probá ser más específico (ej: \"en 5 minutos\", \"mañana a las 8\")."
    end

    if scheduled_for <= Time.current
      return "❌ La hora del recordatorio ya pasó. Probá con un momento futuro."
    end

    kind     = tool["kind"].to_s.presence || "notify"
    raw_did  = tool["device_id"].presence
    fk_id    = nil

    if kind == "query_device"
      device = lookup_device(raw_did)
      return "❌ No encontré el dispositivo `#{raw_did}` para programar el recordatorio." unless device
      fk_id  = device.id
    end

    reminder = Reminder.new(
      scheduled_for: scheduled_for,
      message:       tool["message"].to_s.presence || "recordatorio",
      kind:          kind,
      device_id:     fk_id
    )

    if reminder.save
      ExecuteReminderJob.set(wait_until: reminder.scheduled_for).perform_later(reminder.id)
      formatted = reminder.scheduled_for.in_time_zone.strftime("%d/%m a las %H:%M")
      "⏰ Recordatorio ##{reminder.id} programado para el *#{formatted}*:\n_#{reminder.message}_"
    else
      Rails.logger.error("create_reminder_from_tool: #{reminder.errors.full_messages.join(', ')}")
      "❌ No pude programar el recordatorio: #{reminder.errors.full_messages.join(', ')}"
    end
  end

  # El AI puede pasar el id_string ("esp32_riego") o, en el peor caso, el id numérico.
  def lookup_device(value)
    return nil if value.blank?
    Device.find_by(device_id: value.to_s) || Device.find_by(id: value.to_i)
  end

  def parse_iso8601(str)
    return nil if str.blank?
    return nil if str.include?("<") || str.include?(">")    # rechazá placeholders del prompt
    return nil if str.match?(/\b(YYYY|MM|DD|HH|SS)\b/)      # rechazá la plantilla literal
    Time.zone.parse(str)
  rescue ArgumentError, TypeError, Date::Error
    nil
  end

  # Fallback cuando el AI no respetó el formato ISO8601 y devolvió algo como
  # "en 5 minutos" o "en 2 horas". Mejor cinturón y tirantes que dejarlo morir.
  # Si el campo `scheduled_for` no tiene info útil, revisamos `message` también
  # (algunos modelos meten la expresión temporal ahí).
  def parse_relative(*strings)
    strings.each do |str|
      next if str.blank?
      next unless (m = str.match(/en\s+(\d+)\s*(minutos?|min|horas?|hs?|d[ií]as?)/i))

      n    = m[1].to_i
      unit = m[2].downcase
      case unit
      when /\Amin/   then return n.minutes.from_now
      when /\Ah/     then return n.hours.from_now
      when /\Ad/     then return n.days.from_now
      end
    end
    nil
  end

  def invoke_device(device_id, ai_context, user_message)
    device = Device.find_by(device_id: device_id)
    return "❌ Dispositivo `#{device_id}` no encontrado." unless device

    full_context = [
      %(Mensaje literal del usuario: "#{user_message}"),
      ai_context.present? ? "Interpretación previa: #{ai_context}" : nil
    ].compact.join("\n")

    result = DispatchAction.new.call(device: device, context: full_context, trusted: true)
    result.either(
      ->(response) {
        MqttPublisher.publish(device, response)
        msg  = "✅ *#{device.name}* → `#{response[:action]}`"
        msg += "\nValor: #{response[:value]}" if response[:value]
        msg += "\n_#{response[:reason]}_"
        msg += "\n⚠️ _Alta seguridad — requiere confirmación física._" if response[:requires_confirmation]
        msg
      },
      ->(_) { "❌ No se pudo comandar #{device.name}." }
    )
  end

  def list_devices
    devices = Device.order(:name)
    return TelegramClient.send_message("No hay dispositivos registrados.") if devices.empty?

    lines = devices.map do |d|
      actions = d.actions_list.any? ? " · `#{d.actions_list.join(', ')}`" : ""
      "• *#{d.name}* (`#{d.device_id}`)#{actions}"
    end
    TelegramClient.send_message("*Dispositivos:*\n#{lines.join("\n")}\n\nDecime qué hacer con ellos.")
  end

  def list_reminders
    reminders = Reminder.upcoming.limit(10)

    if reminders.empty?
      TelegramClient.send_message("No hay recordatorios pendientes.")
      return
    end

    lines = reminders.map do |r|
      formatted = r.scheduled_for.in_time_zone.strftime("%d/%m %H:%M")
      kind_tag  = r.query_device? ? " 📡" : ""
      "[#{r.id}] #{formatted}#{kind_tag} — #{r.message}"
    end
    TelegramClient.send_message("📋 *Recordatorios pendientes:*\n#{lines.join("\n")}\n\n_Usá /borrar\\_recordatorio <id> para cancelar uno._")
  end

  def delete_reminder(id)
    reminder = Reminder.find_by(id: id)

    if reminder.nil?
      TelegramClient.send_message("❌ No existe el recordatorio ##{id}.")
    elsif reminder.executed_at.present?
      TelegramClient.send_message("❌ El recordatorio ##{id} ya fue ejecutado y no se puede cancelar.")
    else
      reminder.destroy!
      TelegramClient.send_message("✅ Recordatorio ##{id} cancelado.")
    end
  end

  def reset_conversation
    conv_id = Rails.cache.read(CONV_CACHE_KEY)
    Conversation.find_by(id: conv_id)&.destroy if conv_id
    Rails.cache.delete(CONV_CACHE_KEY)
  end

  def find_or_create_conversation
    fingerprint = TelegramContextBuilder.fingerprint
    conv_id     = Rails.cache.read(CONV_CACHE_KEY)
    conv        = Conversation.find_by(id: conv_id) if conv_id

    if conv && conv.system_prompt_fingerprint != fingerprint
      Rails.logger.info("Telegram: prompt cambió, reseteando conversación ##{conv.id}")
      conv.destroy
      conv = nil
    end

    return conv if conv

    model_id = ModelSelector.first_available
    return nil unless model_id

    conv = Conversation.create!(
      title:                      "Telegram",
      model_id:                   model_id,
      provider:                   Conversation.all_models[model_id],
      hidden:                     true,
      system_prompt_fingerprint:  fingerprint
    )
    Rails.cache.write(CONV_CACHE_KEY, conv.id)
    conv
  end
end
