# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class MessagesController < ApplicationController
  before_action :set_conversation

  def create
    result = ProcessUserMessage.new(
      conversation: @conversation,
      user:         current_user,
      broadcaster:  ChatBroadcaster.new(@conversation)
    ).call(message_params[:content])

    result.either(
      ->(_outcome)   { head :ok },
      ->(error)      { handle_failure(error) }
    )
  end

  private

  def set_conversation
    @conversation = current_user.conversations.find(params[:conversation_id])
  end

  def message_params
    params.expect(message: [ :content ])
  end

  def handle_failure(error)
    @error        = error
    @user_message = @conversation.messages.where(role: "user").last
    respond_to do |format|
      format.turbo_stream { render "messages/failure", status: :unprocessable_content }
      format.html         { redirect_to @conversation, alert: t("errors.ai.#{error}", default: t("errors.ai.default")) }
    end
  end
end
