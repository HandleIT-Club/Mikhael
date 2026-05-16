# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
#
# Cookies de sesión endurecidas:
#   httponly  → no se pueden leer desde JS (mitiga XSS robando session)
#   secure    → solo viajan por HTTPS en producción (force_ssl ya está en prod)
#   same_site → defensa contra CSRF cross-site
#   key       → nombre custom para no colisionar con otros apps Rails locales
Rails.application.config.session_store :cookie_store,
  key:       "_mikhael_session",
  httponly:  true,
  secure:    Rails.env.production?,
  same_site: :lax
