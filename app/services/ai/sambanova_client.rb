# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
require_relative "openai_compatible_client"

module Ai
  class SambaNovaClient < OpenAiCompatibleClient
    def self.api_base    = "https://api.sambanova.ai/v1"
    def self.model_prefix = "sambanova"

    def api_key      = ENV.fetch("SAMBANOVA_API_KEY", "")
    def provider_name = "sambanova"
  end
end
