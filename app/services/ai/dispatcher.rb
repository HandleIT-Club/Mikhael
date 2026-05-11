module Ai
  class Dispatcher
    CLIENTS = {
      "ollama" => OllamaClient,
      "groq"   => GroqClient
    }.freeze

    def self.for(provider)
      CLIENTS.fetch(provider) { raise ArgumentError, "Proveedor desconocido: #{provider}" }.new
    end
  end
end
