# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
Rails.application.config.after_initialize do
  next unless TelegramClient.configured?
  next unless Rails.env.production? || ENV["ENABLE_TELEGRAM_POLLING"] == "true"

  TelegramPollJob.perform_later
  Rails.logger.info("Telegram polling iniciado.")
end
