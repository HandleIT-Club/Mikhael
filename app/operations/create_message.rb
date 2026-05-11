class CreateMessage
  include Dry::Monads[:result, :do]

  def call(conversation:, content:)
    yield validate(conversation.id, content)
    yield persist_user_message(conversation, content)
    ai_response = yield dispatch(conversation)
    yield persist_assistant_message(conversation, ai_response)

    Success(ai_response)
  end

  private

  def validate(conversation_id, content)
    result = MessageContract.new.call(conversation_id: conversation_id, content: content)
    result.success? ? Success() : Failure(:invalid_input)
  end

  def persist_user_message(conversation, content)
    message = conversation.messages.create(role: "user", content: content)
    message.persisted? ? Success(message) : Failure(:persistence_error)
  end

  def dispatch(conversation)
    messages = build_messages(conversation)
    client   = Ai::Dispatcher.for(conversation.provider)
    client.chat(messages: messages, model: conversation.model_id)
  end

  def persist_assistant_message(conversation, ai_response)
    message = conversation.messages.create(
      role:     "assistant",
      content:  ai_response.content,
      model_id: ai_response.model,
      provider: ai_response.provider
    )
    message.persisted? ? Success(message) : Failure(:persistence_error)
  end

  def build_messages(conversation)
    system_prompt = { role: "system", content: system_prompt_for(conversation) }
    chat_history  = conversation.chat_messages.map do |m|
      { role: m.role, content: m.content }
    end
    [ system_prompt ] + chat_history
  end

  def system_prompt_for(conversation)
    case conversation.provider
    when "groq"   then "Eres Mikhael, un asistente de código experto. El usuario trabaja en macOS con Ruby on Rails."
    when "ollama" then "Eres un asistente conversacional. El usuario trabaja en macOS con Ruby on Rails."
    end
  end
end
