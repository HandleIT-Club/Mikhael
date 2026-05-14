# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Ai
  class BaseClient
    include Dry::Monads[:result]

    def chat(messages:, model:)
      raise NotImplementedError, "#{self.class} must implement #chat"
    end

    private

    def build_response(content, model, provider)
      Success(AiResponse.new(content: content, model: model, provider: provider))
    end
  end
end
