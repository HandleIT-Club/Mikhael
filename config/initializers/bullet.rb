# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
#
# Bullet: detecta N+1 queries y missing eager-loading en dev.
# Solo en development — en test añade ruido y en prod no se carga.

if Rails.env.development? && defined?(Bullet)
  Rails.application.config.after_initialize do
    Bullet.enable        = true
    Bullet.alert         = true    # popup en el browser
    Bullet.bullet_logger = true    # log/bullet.log
    Bullet.console       = true    # window.console
    Bullet.rails_logger  = true
    Bullet.add_footer    = true
  end
end
