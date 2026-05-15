# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Ai
  # Ollama y Groq comparten cliente porque RubyLLM los soporta nativamente.
  # Cerebras/SambaNova viven aparte porque el slot openai_api_base ya está
  # ocupado por Groq.
  class RubyLlmClient < BaseClient
    def initialize(llm_provider:, our_provider:, unavailable_failure: :ai_error)
      @llm_provider        = llm_provider
      @our_provider        = our_provider
      @unavailable_failure = unavailable_failure
    end

    def chat(messages:, model:)
      build_response(build_llm_chat(messages, model).complete.content, model, @our_provider)
    rescue Errno::ECONNREFUSED
      Failure(@unavailable_failure)
    rescue RubyLLM::UnauthorizedError
      Failure(:invalid_api_key)
    rescue RubyLLM::RateLimitError
      Failure(:rate_limited)
    rescue => e
      Rails.logger.error("#{self.class}(#{@our_provider}) error: #{e.message}")
      Failure(:ai_error)
    end

    def stream(messages:, model:, &block)
      response = build_llm_chat(messages, model).complete do |chunk|
        delta = chunk.content.to_s
        block.call(delta) if delta.present? && block
      end
      build_response(response.content.to_s, model, @our_provider)
    rescue Errno::ECONNREFUSED
      Failure(@unavailable_failure)
    rescue RubyLLM::UnauthorizedError
      Failure(:invalid_api_key)
    rescue RubyLLM::RateLimitError
      Failure(:rate_limited)
    rescue => e
      Rails.logger.error("#{self.class}(#{@our_provider}) stream error: #{e.message}")
      Failure(:ai_error)
    end

    private

    def build_llm_chat(messages, model)
      llm_chat = RubyLLM.chat(model: model, provider: @llm_provider, assume_model_exists: true)
      messages.each do |msg|
        if msg[:role] == "system"
          llm_chat.with_instructions(msg[:content])
        else
          llm_chat.add_message(role: msg[:role].to_sym, content: msg[:content])
        end
      end
      llm_chat
    end
  end
end
