# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
#
# Cookies de sesión endurecidas:
#   httponly  → no se pueden leer desde JS (mitiga XSS robando session)
#   same_site → defensa contra CSRF cross-site
#   key       → nombre custom para no colisionar con otros apps Rails locales
#
# No marcamos `secure: true` porque Mikhael es self-hosted local sobre HTTP.
# Con `secure` el browser descarta la cookie en http://localhost y se rompe
# la sesión (y con ella la validación CSRF).
Rails.application.config.session_store :cookie_store,
  key:       "_mikhael_session",
  httponly:  true,
  same_site: :lax
