# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
RubyLLM.configure do |config|
  config.ollama_api_base = ENV.fetch("OLLAMA_URL", "http://localhost:11434/v1/")

  # Groq se rutea por el slot openai_* de RubyLLM (API compatible)
  config.openai_api_key  = ENV.fetch("GROQ_API_KEY", "")
  config.openai_api_base = "https://api.groq.com/openai/v1"
end
