# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Orquesta TODO el flujo de un mensaje entrante en una conversation web:
#
#   1. Valida contenido (no vacío).
#   2. Persiste el mensaje del user + lo empuja a la UI.
#   3. Intenta un slash command (/dispositivos, /zona...). Si match, responde y termina.
#   4. Intenta intent router (qué hora es, cómo están los devices...). Si match, responde.
#   5. Llama al AI con streaming. Mientras llegan chunks, los empuja a la UI.
#   6. Pasa la respuesta del AI por ToolCallExecutor (call_device, create_reminder).
#   7. Reemplaza el placeholder con el mensaje final y broadcastea cambios (título, modelo).
#
# El controller queda fino: parsea params, crea broadcaster, llama acá.
# Para API o tests sin UI, pasá un NullChatBroadcaster.
#
# Devuelve un Result. El reply concreto ya fue empujado vía broadcaster.
class ProcessUserMessage
  include Dry::Monads[:result]

  # Marcadores para que el caller sepa qué pasó (logging, métricas, etc).
  Outcome = Data.define(:kind, :assistant_message)

  TITLE_TRIGGER_COUNT = 2  # generamos título al segundo turno

  def initialize(conversation:, user:, broadcaster: NullChatBroadcaster.new)
    @conversation = conversation
    @user         = user
    @broadcaster  = broadcaster
  end

  def call(content)
    content = content.to_s
    return Failure(:invalid_input) if content.strip.empty?

    Rails.logger.tagged("user=#{@user&.id || '-'}", "conv=#{@conversation.id}") do
      user_message = persist_user_message(content)
      @broadcaster.append_message(user_message)

      if (cmd = CommandRouter.handle(content, user: @user))
        Rails.logger.info("ProcessUserMessage: command match — content=#{content.truncate(40).inspect}")
        return Success(reply_with_text(cmd.reply))
      end

      if (intent = MessageIntentRouter.intercept(content))
        Rails.logger.info("ProcessUserMessage: intent match — content=#{content.truncate(40).inspect}")
        return Success(reply_with_text(intent.reply, persist: intent.assistant_persist))
      end

      Rails.logger.info("ProcessUserMessage: AI turn — model=#{@conversation.model_id} provider=#{@conversation.provider}")
      run_ai_turn(content, user_message)
    end
  end

  private

  def persist_user_message(content)
    @conversation.messages.create!(role: "user", content: content)
  end

  # Para slash commands e intent router. Persiste un assistant message y lo
  # muestra inmediato. No pasa por el AI ni streaming.
  def reply_with_text(reply_text, persist: nil)
    assistant_msg = @conversation.messages.create!(role: "assistant", content: persist || reply_text)
    @broadcaster.append_message(assistant_msg)
    maybe_update_title
    Outcome.new(kind: :deterministic, assistant_message: assistant_msg)
  end

  def run_ai_turn(content, user_message)
    @broadcaster.show_streaming_placeholder
    original_model = @conversation.model_id

    buffer  = +""
    context = AssistantContext.for(:web)
    result  = CreateMessage.new.call(
      conversation:  @conversation,
      content:       content,
      user_message:  user_message,
      system_prompt: context.build,
      primer:        context.primer,
      on_chunk:      ->(chunk) { buffer << chunk; @broadcaster.stream_chunk(buffer) }
    )

    @conversation.reload

    result.either(
      ->(ai_response) { finalize_ai_turn(ai_response, content, original_model) },
      ->(_error)      { @broadcaster.remove_streaming_placeholder; Failure(:ai_error) }
    )
  end

  def finalize_ai_turn(ai_response, user_content, original_model)
    assistant_msg = @conversation.messages.where(role: "assistant").last
    tool_result   = ToolCallExecutor.new(user_message: user_content, user: @user, surface: :web).call(ai_response.content)

    if tool_result&.silenced?
      # Dedup silencioso: borramos el assistant message (que contenía el JSON
      # crudo del tool call) y el placeholder. El primer turno ya respondió.
      assistant_msg&.destroy
      @broadcaster.remove_streaming_placeholder
      return Success(Outcome.new(kind: :dedup, assistant_message: nil))
    end

    # Si hay tool result con reply, sobreescribimos el contenido del assistant
    # con la confirmación humana (no el JSON crudo).
    assistant_msg.update!(content: tool_result.assistant_persist) if tool_result&.reply.present?
    @broadcaster.replace_streaming_placeholder(assistant_msg)

    maybe_update_title
    @broadcaster.update_model_selector if @conversation.model_id != original_model

    Success(Outcome.new(kind: :ai, assistant_message: assistant_msg))
  end

  # Genera un título a partir del primer prompt del user al segundo turno.
  def maybe_update_title
    return unless @conversation.chat_messages.count == TITLE_TRIGGER_COUNT

    first = @conversation.chat_messages.first.content.to_s.strip
    words = first.split
    title = words.first(8).join(" ")
    title = "#{title[0..59].rstrip}…" if title.length > 60
    title = title.presence || @conversation.title

    @conversation.update(title: title)
    @broadcaster.update_title(title)
  end
end
