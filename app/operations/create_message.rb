# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class CreateMessage
  include Dry::Monads[:result, :do]

  # on_chunk: Proc/lambda opcional — si se pasa, se usa streaming y se llama con cada delta (String).
  #   Nota: NO usar &block porque dry-monads Do inyecta su propio proc interno como bloque de call.
  # user_message: si ya fue guardado externamente (streaming web), se omite persist_user_message.
  def call(conversation:, content:, system_prompt: nil, primer: nil, user_message: nil, on_chunk: nil)
    yield validate(conversation.id, content)
    yield persist_user_message(conversation, content) unless user_message
    ai_response = yield dispatch(conversation, system_prompt, primer, on_chunk)
    yield persist_assistant_message(conversation, ai_response)

    Success(ai_response)
  end

  private

  def validate(_conversation_id, content)
    content.to_s.strip.empty? ? Failure(:invalid_input) : Success()
  end

  def persist_user_message(conversation, content)
    message = conversation.messages.create(role: "user", content: content)
    message.persisted? ? Success(message) : Failure(:persistence_error)
  end

  SKIPPABLE_FAILURES = %i[rate_limited invalid_api_key ai_error ollama_unavailable].freeze

  # on_chunk: Proc o nil. Si es Proc, se usa streaming; si es nil, request/response normal.
  # En caso de fallo durante streaming, reintenta sin streaming con el siguiente provider.
  def dispatch(conversation, system_prompt_override = nil, primer = nil, on_chunk = nil)
    messages         = build_messages(conversation, system_prompt_override, primer)
    current_on_chunk = on_chunk

    loop do
      client = Ai::Dispatcher.for(conversation.provider)
      result = if current_on_chunk
        client.stream(messages: messages, model: conversation.model_id, &current_on_chunk)
      else
        client.chat(messages: messages, model: conversation.model_id)
      end

      return result unless result.failure? && SKIPPABLE_FAILURES.include?(result.failure)

      ModelSelector.mark_rate_limited(conversation.model_id) if result.failure == :rate_limited
      next_model = ModelSelector.next_available(conversation.model_id)
      return Failure(:all_models_exhausted) unless next_model

      conversation.update!(model_id: next_model)
      current_on_chunk = nil  # fallback sin streaming — mejor respuesta completa que streaming roto
    end
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

  HISTORY_LIMIT_WITH_OVERRIDE = 20

  def build_messages(conversation, system_prompt_override = nil, primer = nil)
    prompt        = system_prompt_override || system_prompt_for(conversation)
    system_prompt = { role: "system", content: prompt }
    messages      = conversation.chat_messages
    messages      = messages.last(HISTORY_LIMIT_WITH_OVERRIDE) if system_prompt_override
    chat_history  = messages.map { |m| { role: m.role, content: m.content } }
    [ system_prompt ] + Array(primer) + chat_history
  end

  def system_prompt_for(conversation)
    ModelConfig.prompt_for(conversation.model_id)
  end
end
