# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Store dedicado para rate limiting.
#
# Producción: SolidCacheStore con namespace propio. Compartido entre todos los
# procesos Puma y nodos — los contadores son globales, no per-process. Con
# MemoryStore (lo anterior) un atacante saturaba el límite N veces si había N
# pumas; ahora el límite es real.
#
# Test/dev: MemoryStore. No queremos meter SolidCache en cada test (lento,
# requiere migrations) y los tests resetean con `RATE_LIMIT_STORE.clear`.
RATE_LIMIT_STORE =
  if Rails.env.production?
    ActiveSupport::Cache::SolidCacheStore.new(namespace: "ratelimit")
  else
    ActiveSupport::Cache::MemoryStore.new
  end
