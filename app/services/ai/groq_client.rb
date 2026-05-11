module Ai
  class GroqClient < BaseClient
    def chat(messages:, model:)
      llm_chat = RubyLLM.chat(model: model, provider: :openai, assume_model_exists: true)

      messages.each do |msg|
        case msg[:role]
        when "system" then llm_chat.with_instructions(msg[:content])
        when "user"   then @last_user = msg[:content]
        end
      end

      response = llm_chat.ask(@last_user)
      build_response(response.content, model, "groq")
    rescue RubyLLM::UnauthorizedError
      Failure(:invalid_api_key)
    rescue RubyLLM::RateLimitError
      Failure(:rate_limited)
    rescue => e
      Rails.logger.error("GroqClient error: #{e.message}")
      Failure(:ai_error)
    end
  end
end
