# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Cooldown distribuido: marca un modelo como rate-limited durante DURATION
# para que la fallback chain lo salte. Usa Rails.cache (Solid Cache en prod)
# para que el cooldown sea compartido entre workers/nodos.
module Ai
  class Cooldown
    DURATION   = 2.minutes
    KEY_PREFIX = "ai:cooldown:".freeze

    class << self
      def mark(model_id)
        Rails.cache.write(key(model_id), true, expires_in: DURATION)
      end

      def active?(model_id)
        Rails.cache.exist?(key(model_id))
      end

      private

      def key(model_id) = "#{KEY_PREFIX}#{model_id}"
    end
  end
end
