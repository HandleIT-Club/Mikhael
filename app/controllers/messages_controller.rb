# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class MessagesController < ApplicationController
  before_action :set_conversation

  def create
    original_model = @conversation.model_id

    result = CreateMessage.new.call(
      conversation: @conversation,
      content:      message_params[:content]
    )

    @conversation.reload
    @model_switched = @conversation.model_id != original_model

    result.either(
      ->(ai_response) { handle_success(ai_response) },
      ->(error)       { handle_failure(error) }
    )
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end

  def message_params
    params.expect(message: [ :content ])
  end

  def handle_success(ai_response)
    maybe_generate_title
    @messages = @conversation.chat_messages
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @conversation }
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

  def handle_failure(error)
    @error = error
    @user_message = @conversation.messages.where(role: "user").last
    respond_to do |format|
      format.turbo_stream { render "messages/failure" }
      format.html { redirect_to @conversation, alert: t("errors.ai.#{error}", default: t("errors.ai.default")) }
    end
  end
end
