# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class TelegramMessageHandler
  CONV_CACHE_KEY = "telegram_conversation_id".freeze

  def call(text)
    case text.strip
    when "/start"
      TelegramClient.send_message("👋 Soy *Mikhael*. Sé qué dispositivos tenés y los puedo comandar por vos. Hablame natural.\n\nComandos:\n`/dispositivos` — listar devices\n`/reset` — empezar de cero")
    when "/dispositivos"
      list_devices
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

  def handle_ai_response(response, user_message)
    tool_call = ToolCallParser.parse(response.content)

    if tool_call && (tool_call["device_id"].present? || tool_call["tool"] == "call_device")
      ai_context = tool_call["context"] || tool_call["message"]
      summary    = invoke_device(tool_call["device_id"], ai_context, user_message)
      TelegramClient.send_message(summary)
    else
      TelegramClient.send_message(response.content)
    end
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
