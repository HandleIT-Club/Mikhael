# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
#
# En producción el polling lo agenda SolidQueue vía config/recurring.yml
# (entry: telegram_poll). No hace falta self-enqueue desde acá.
#
# En desarrollo, si querés probar el bot localmente, exportá
# ENABLE_TELEGRAM_POLLING=true y este initializer va a encolarlo una vez
# para que el job arranque el ciclo manualmente.
Rails.application.config.after_initialize do
  next unless TelegramClient.configured?
  next if Rails.env.production? # producción lo maneja recurring.yml
  next unless ENV["ENABLE_TELEGRAM_POLLING"] == "true"

  # Dev one-shot. Re-ejecutarlo manualmente o reiniciar el server si querés
  # otro tick — no se auto-encadena.
  TelegramPollJob.perform_later
  Rails.logger.info("Telegram polling (dev one-shot) encolado.")
end
