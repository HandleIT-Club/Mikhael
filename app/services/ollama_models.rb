# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
require "net/http"
require "json"

class OllamaModels
  CACHE_KEY = "ollama:installed_models"
  CACHE_TTL = 60.seconds

  def self.installed
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_from_api }
  rescue => e
    Rails.logger.warn("OllamaModels: no se pudo obtener la lista — #{e.message}")
    []
  end

  def self.bust_cache
    Rails.cache.delete(CACHE_KEY)
  end

  private

  def self.fetch_from_api
    base = ENV.fetch("OLLAMA_URL", "http://localhost:11434/v1/").sub(%r{/v1/?$}, "")
    uri  = URI("#{base}/api/tags")

    response = Net::HTTP.start(uri.host, uri.port, open_timeout: 3, read_timeout: 5) do |http|
      http.get(uri.request_uri)
    end

    return [] unless response.code == "200"

    JSON.parse(response.body).fetch("models", []).map { |m| m["name"] }
  end
end
