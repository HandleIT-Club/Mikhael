# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class ConversationsController < ApplicationController
  before_action :set_conversation, only: %i[show destroy update]

  def index
    @conversations = Conversation.visible.recent
    @conversation  = Conversation.new
  end

  def show
    @messages = @conversation.chat_messages
    @message  = Message.new
  end

  def create
    @conversation = Conversation.new(conversation_params)

    if @conversation.save
      redirect_to @conversation
    else
      @conversations = Conversation.visible.recent
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @conversation.update(conversation_update_params)
      redirect_to @conversation
    else
      redirect_to @conversation, alert: "No se pudo cambiar el modelo."
    end
  end

  def destroy
    @conversation.destroy
    redirect_to conversations_path, status: :see_other
  end

  private

  def set_conversation
    @conversation = Conversation.visible.find(params[:id])
  end

  def conversation_params
    params.expect(conversation: %i[title model_id])
  end

  def conversation_update_params
    params.expect(conversation: [ :model_id ])
  end
end
