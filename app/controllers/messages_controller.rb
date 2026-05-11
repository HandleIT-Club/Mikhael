class MessagesController < ApplicationController
  before_action :set_conversation

  def create
    result = CreateMessage.new.call(
      conversation: @conversation,
      content:      message_params[:content]
    )

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
    params.expect(message: [:content])
  end

  def handle_success(ai_response)
    @messages = @conversation.chat_messages
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @conversation }
    end
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
