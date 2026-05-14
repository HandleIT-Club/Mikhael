# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class TelegramPollJob < ApplicationJob
  queue_as :default

  POLL_INTERVAL  = 2.seconds
  OFFSET_CACHE   = "telegram_poll_offset".freeze
  ALLOWED_CHAT   = ENV["TELEGRAM_CHAT_ID"].freeze

  def perform
    return unless TelegramClient.configured?

    offset   = Rails.cache.read(OFFSET_CACHE)
    response = TelegramClient.get_updates(offset: offset)

    if response&.dig("ok")
      (response["result"] || []).each do |update|
        process(update)
        Rails.cache.write(OFFSET_CACHE, update["update_id"] + 1)
      end
    end
  ensure
    self.class.set(wait: POLL_INTERVAL).perform_later
  end

  private

  def process(update)
    message = update["message"] || update["edited_message"]
    return unless message

    return unless message.dig("chat", "id").to_s == ALLOWED_CHAT

    text = message["text"].to_s.strip
    return if text.empty?

    TelegramMessageHandler.new.call(text)
  rescue => e
    Rails.logger.error("TelegramPollJob#process: #{e.message}")
  end
end
