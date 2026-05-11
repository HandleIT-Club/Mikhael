class ConversationsController < ApplicationController
  before_action :set_conversation, only: %i[show destroy]

  def index
    @conversations = Conversation.recent
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
      @conversations = Conversation.recent
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @conversation.destroy
    redirect_to conversations_path, status: :see_other
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end

  def conversation_params
    params.expect(conversation: %i[title model_id])
  end
end
