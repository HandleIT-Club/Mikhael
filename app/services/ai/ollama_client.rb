module Ai
  class OllamaClient < BaseClient
    def chat(messages:, model:)
      llm_chat = RubyLLM.chat(model: model, provider: :ollama, assume_model_exists: true)

      messages.each do |msg|
        case msg[:role]
        when "system"    then llm_chat.with_instructions(msg[:content])
        when "user"      then @last_user = msg[:content]
        when "assistant" then nil # ruby_llm mantiene historial internamente
        end
      end

      response = llm_chat.ask(@last_user)
      build_response(response.content, model, "ollama")
    rescue Errno::ECONNREFUSED
      Failure(:ollama_unavailable)
    rescue => e
      Rails.logger.error("OllamaClient error: #{e.message}")
      Failure(:ai_error)
    end
  end
end
