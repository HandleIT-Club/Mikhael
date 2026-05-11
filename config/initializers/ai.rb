RubyLLM.configure do |config|
  config.ollama_api_base = ENV.fetch("OLLAMA_URL", "http://localhost:11434/v1/")

  # Groq usa la API compatible con OpenAI
  config.openai_api_key  = ENV.fetch("GROQ_API_KEY", "")
  config.openai_api_base = "https://api.groq.com/openai/v1"
end
