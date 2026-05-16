# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Lista de modelos Ollama instalados localmente. Cache de 60s para evitar
# spam al daemon de Ollama. Faraday con retries (Ollama local puede tardar
# en responder en el primer hit, sobre todo si arranca cold).
class OllamaModels
  CACHE_KEY = "ollama:installed_models".freeze
  CACHE_TTL = 60.seconds

  def self.installed
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_from_api }
  rescue => e
    Rails.logger.warn("OllamaModels: no se pudo obtener la lista — #{e.class} #{e.message}")
    []
  end

  def self.bust_cache
    Rails.cache.delete(CACHE_KEY)
  end

  def self.fetch_from_api
    response = connection.get("api/tags")
    return [] unless response.success?

    JSON.parse(response.body).fetch("models", []).map { |m| m["name"] }
  rescue JSON::ParserError => e
    Rails.logger.warn("OllamaModels: respuesta no es JSON — #{e.message}")
    []
  end

  def self.connection
    base = ENV.fetch("OLLAMA_URL", "http://localhost:11434/v1/").sub(%r{/v1/?$}, "")
    Http::Client.connection(
      base_url:     "#{base}/",
      timeout:      5,
      open_timeout: 3,
      # Ollama local: solo 1 retry — si el daemon no responde rápido es
      # porque no está corriendo, no porque está saturado.
      retries:      1
    )
  end
end
