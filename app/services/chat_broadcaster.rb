# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Encapsula los Turbo Stream broadcasts para una conversación. El controller
# (o cualquier caller) lo instancia con la conversation y delega los pushes
# a la UI. Esto desacopla la operation `ProcessUserMessage` de Hotwire:
# podés pasarle un NullBroadcaster en specs/API y la operation funciona igual.
#
# Single Responsibility: solo Turbo. Nada de lógica de negocio acá.
class ChatBroadcaster
  TARGET_LIST              = "messages".freeze
  TARGET_STREAM_CONTAINER  = "streaming-message".freeze
  TARGET_STREAM_CONTENT    = "streaming-content".freeze
  TARGET_TITLE             = "conversation-title".freeze
  TARGET_MODEL             = "conversation-model".freeze

  def initialize(conversation)
    @conversation = conversation
    @channel      = "conversation_#{conversation.id}"
  end

  def append_message(message)
    Turbo::StreamsChannel.broadcast_append_to(
      @channel, target: TARGET_LIST, partial: "messages/message", locals: { message: message }
    )
  end

  def show_streaming_placeholder
    Turbo::StreamsChannel.broadcast_append_to(
      @channel, target: TARGET_LIST, partial: "messages/streaming_placeholder"
    )
  end

  def stream_chunk(text)
    Turbo::StreamsChannel.broadcast_update_to(
      @channel, target: TARGET_STREAM_CONTENT,
      partial: "messages/streaming_chunk", locals: { text: text }
    )
  end

  def replace_streaming_placeholder(message)
    Turbo::StreamsChannel.broadcast_replace_to(
      @channel, target: TARGET_STREAM_CONTAINER,
      partial: "messages/message", locals: { message: message }
    )
  end

  def remove_streaming_placeholder
    Turbo::StreamsChannel.broadcast_remove_to(@channel, target: TARGET_STREAM_CONTAINER)
  end

  def update_title(title)
    safe_title = ERB::Util.html_escape(title)
    Turbo::StreamsChannel.broadcast_update_to(@channel, target: TARGET_TITLE,                             html: safe_title)
    Turbo::StreamsChannel.broadcast_update_to(@channel, target: "conv-title-#{@conversation.id}",         html: safe_title)
  end

  def update_model_selector
    Turbo::StreamsChannel.broadcast_replace_to(
      @channel, target: TARGET_MODEL,
      partial: "conversations/model_selector", locals: { conversation: @conversation }
    )
  end
end
