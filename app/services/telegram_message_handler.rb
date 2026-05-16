# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Shim delgado sobre los services compartidos. Su única responsabilidad
# surface-específica es: gestionar la conversación de Telegram del user +
# enviar las respuestas vía TelegramClient.
#
# Multi-user: el handler recibe el chat_id, resuelve User#find_by(telegram_chat_id:),
# y todo el flujo corre scoped a ese user. Si el chat_id no está linkeado a
# ningún user, ignoramos el mensaje.
#
# La conversación de Telegram se identifica por user_id + title="Telegram"
# (no por un cache externo). Robusto contra restart del cache, sin race
# conditions, fácil de testear.
class TelegramMessageHandler
  TELEGRAM_CONV_TITLE = "Telegram".freeze

  def initialize(user:, chat_id:)
    @user    = user
    @chat_id = chat_id
  end

  def call(text)
    return unless @user # defensa: el caller debería haber filtrado

    Current.user = @user

    stripped = text.to_s.strip
    router   = CommandRouter.new(stripped, user: @user)

    if router.reset_command?
      reset_conversation
      return send_message("✅ Conversación reiniciada.")
    end

    if (cmd = router.handle)
      return send_message(cmd.reply)
    end

    if (intent = MessageIntentRouter.intercept(stripped))
      return send_message(intent.reply)
    end

    handle_chat(stripped)
  ensure
    Current.user = nil
  end

  private

  def send_message(text)
    TelegramClient.send_message(text, chat_id: @chat_id)
  end

  def handle_chat(text)
    conversation = find_or_create_conversation
    return send_message("❌ No hay modelos disponibles.") unless conversation

    context = AssistantContext.for(:telegram)
    result  = CreateMessage.new.call(
      conversation:  conversation,
      content:       text,
      system_prompt: context.build,
      primer:        context.primer
    )

    result.either(
      ->(response) { handle_ai_response(response, text) },
      ->(error)    { send_message("❌ Error: #{error}") }
    )
  end

  def handle_ai_response(ai_response, user_message)
    executor = ToolCallExecutor.new(user_message: user_message, user: @user, surface: :telegram)
    result   = executor.call(ai_response.content)

    if result
      send_message(result.reply) if result.reply.present?
    else
      send_message(ai_response.content)
    end
  end

  def reset_conversation
    @user.conversations.where(title: TELEGRAM_CONV_TITLE).destroy_all
  end

  def find_or_create_conversation
    context     = AssistantContext.for(:telegram)
    fingerprint = context.fingerprint
    conv        = @user.conversations.where(title: TELEGRAM_CONV_TITLE).first

    if conv && conv.system_prompt_fingerprint != fingerprint
      Rails.logger.info("Telegram: prompt cambió, reseteando conv ##{conv.id} para user ##{@user.id}")
      conv.destroy
      conv = nil
    end

    return conv if conv

    model_id = ModelSelector.first_available
    return nil unless model_id

    @user.conversations.create!(
      title:                      TELEGRAM_CONV_TITLE,
      model_id:                   model_id,
      provider:                   Conversation.all_models[model_id],
      hidden:                     true,
      system_prompt_fingerprint:  fingerprint
    )
  end
end
