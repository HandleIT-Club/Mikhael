# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
require_relative "ruby_llm_client"
require_relative "cerebras_client"
require_relative "sambanova_client"

module Ai
  class Dispatcher
    BUILDERS = {
      "ollama"    => -> { RubyLlmClient.new(llm_provider: :ollama, our_provider: "ollama", unavailable_failure: :ollama_unavailable) },
      "groq"      => -> { RubyLlmClient.new(llm_provider: :openai, our_provider: "groq") },
      "cerebras"  => -> { CerebrasClient.new },
      "sambanova" => -> { SambaNovaClient.new }
    }.freeze

    def self.for(provider)
      builder = BUILDERS.fetch(provider) { raise ArgumentError, "Proveedor desconocido: #{provider}" }
      builder.call
    end
  end
end
