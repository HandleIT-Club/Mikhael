# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Store dedicado para rate limiting — separado del cache general de la app.
# En producción (Solid Cache) y desarrollo (Memory), el rate limiting usa su
# propia MemoryStore para no interferir con el cache de vistas/modelos y para
# que los tests puedan hacer .clear sin afectar nada más.
RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
