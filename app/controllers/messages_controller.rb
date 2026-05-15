# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class MessagesController < ApplicationController
  before_action :set_conversation

  def create
    content = message_params[:content].to_s
    return handle_failure(:invalid_input) if content.strip.empty?

    original_model = @conversation.model_id

    # 1. Guardar user message y enviarlo al browser de inmediato vía cable.
    user_msg = @conversation.messages.create!(role: "user", content: content)
    cable_append partial: "messages/message", locals: { message: user_msg }

    # 2. Mostrar placeholder de streaming (con cursor parpadeante).
    cable_append partial: "messages/streaming_placeholder"

    # 3. Streaming: cada chunk actualiza el texto del placeholder en el browser.
    buffer = +""
    result = CreateMessage.new.call(
      conversation: @conversation,
      content:      content,
      user_message: user_msg,
      on_chunk:     ->(chunk) { buffer << chunk; cable_broadcast_chunk(buffer) }
    )

    # 4. Reemplazar el placeholder con el mensaje final (renderizado con Markdown).
    @conversation.reload
    @model_switched = @conversation.model_id != original_model

    result.either(
      ->(ai_response) { handle_success(ai_response) },
      ->(_error)      { handle_streaming_failure }
    )
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end

  def message_params
    params.expect(message: [ :content ])
  end

  # ── Helpers de cable ──────────────────────────────────────────────────────────

  def cable_channel
    "conversation_#{@conversation.id}"
  end

  def cable_append(partial:, locals: {})
    Turbo::StreamsChannel.broadcast_append_to(
      cable_channel,
      target:  "messages",
      partial: partial,
      locals:  locals
    )
  end

  def cable_broadcast_chunk(buffer)
    Turbo::StreamsChannel.broadcast_update_to(
      cable_channel,
      target: "streaming-content",
      html:   buffer
    )
  end

  def cable_replace_placeholder(partial:, locals: {})
    Turbo::StreamsChannel.broadcast_replace_to(
      cable_channel,
      target:  "streaming-message",
      partial: partial,
      locals:  locals
    )
  end

  def cable_remove_placeholder
    Turbo::StreamsChannel.broadcast_remove_to(cable_channel, target: "streaming-message")
  end

  # ── Handlers de resultado ────────────────────────────────────────────────────

  def handle_success(ai_response)
    maybe_generate_title
    assistant_msg = @conversation.messages.where(role: "assistant").last

    cable_replace_placeholder(
      partial: "messages/message",
      locals:  { message: assistant_msg }
    )

    if @model_switched
      cable_broadcast_model_switch
    end

    if @title_updated
      Turbo::StreamsChannel.broadcast_update_to(cable_channel, target: "conversation-title",        html: @conversation.title)
      Turbo::StreamsChannel.broadcast_update_to(cable_channel, target: "conv-title-#{@conversation.id}", html: @conversation.title)
    end

    head :ok
  end

  def handle_streaming_failure
    cable_remove_placeholder
    # Dejar el user message visible — el error es que la IA no respondió.
    head :unprocessable_content
  end

  def handle_failure(error)
    # Solo se llega acá si content está vacío (antes de que se haya guardado el user message).
    @error        = error
    @user_message = @conversation.messages.where(role: "user").last
    respond_to do |format|
      format.turbo_stream { render "messages/failure" }
      format.html { redirect_to @conversation, alert: t("errors.ai.#{error}", default: t("errors.ai.default")) }
    end
  end

  def maybe_generate_title
    return unless @conversation.chat_messages.count == 2

    first_content = @conversation.chat_messages.first.content.to_s.strip
    words = first_content.split
    title = words.first(8).join(" ")
    title = title[0..59].rstrip + "…" if title.length > 60
    title = title.presence || @conversation.title

    @conversation.update(title: title)
    @title_updated = true
  end

  def cable_broadcast_model_switch
    html = ApplicationController.render(
      partial: "conversations/model_selector",
      locals:  { conversation: @conversation }
    )
    Turbo::StreamsChannel.broadcast_update_to(cable_channel, target: "conversation-model", html: html)
  end
end
