# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Shim delgado sobre los services compartidos (CommandRouter, MessageIntentRouter,
# ToolCallExecutor, AssistantContext). Su única responsabilidad surface-específica
# es: gestionar la conversación cacheada de Telegram + enviar las respuestas vía
# TelegramClient.
#
# Toda la lógica de dominio (qué hace cada comando, qué intercepta, qué hacen
# los tools) está en los services compartidos. La misma lógica corre en web vía
# MessagesController.
class TelegramMessageHandler
  CONV_CACHE_KEY = "telegram_conversation_id".freeze

  def call(text)
    stripped = text.to_s.strip
    router   = CommandRouter.new(stripped)

    if router.reset_command?
      reset_conversation
      return TelegramClient.send_message("✅ Conversación reiniciada.")
    end

    if (cmd = router.handle)
      return TelegramClient.send_message(cmd.reply)
    end

    if (intent = MessageIntentRouter.intercept(stripped))
      return TelegramClient.send_message(intent.reply)
    end

    handle_chat(stripped)
  end

  private

  def handle_chat(text)
    conversation = find_or_create_conversation
    return TelegramClient.send_message("❌ No hay modelos disponibles.") unless conversation

    context = AssistantContext.for(:telegram)
    result  = CreateMessage.new.call(
      conversation:  conversation,
      content:       text,
      system_prompt: context.build,
      primer:        context.primer
    )

    result.either(
      ->(response) { handle_ai_response(response, text) },
      ->(error)    { TelegramClient.send_message("❌ Error: #{error}") }
    )
  end

  # Único side-effect surface-específico tras la respuesta del AI: enviar a
  # Telegram. Toda la lógica de qué responder vive en ToolCallExecutor.
  def handle_ai_response(ai_response, user_message)
    executor = ToolCallExecutor.new(user_message: user_message, surface: :telegram)
    result   = executor.call(ai_response.content)

    if result
      TelegramClient.send_message(result.reply) if result.reply.present?
    else
      TelegramClient.send_message(ai_response.content)
    end
  end

  def reset_conversation
    conv_id = Rails.cache.read(CONV_CACHE_KEY)
    Conversation.find_by(id: conv_id)&.destroy if conv_id
    Rails.cache.delete(CONV_CACHE_KEY)
  end

  def find_or_create_conversation
    context     = AssistantContext.for(:telegram)
    fingerprint = context.fingerprint
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
