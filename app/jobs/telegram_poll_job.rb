# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class TelegramPollJob < ApplicationJob
  queue_as :default

  POLL_INTERVAL = 2.seconds
  OFFSET_KEY    = "telegram_poll_offset".freeze

  def perform
    return unless TelegramClient.configured?

    offset   = Setting.get(OFFSET_KEY)&.to_i
    response = TelegramClient.get_updates(offset: offset)

    if response&.dig("ok")
      (response["result"] || []).each do |update|
        process(update)
        Setting.set(OFFSET_KEY, update["update_id"] + 1)
      end
    end
  ensure
    self.class.set(wait: POLL_INTERVAL).perform_later
  end

  private

  # Multi-user: resolvemos User por telegram_chat_id. Si el chat_id no está
  # linkeado a ningún user, ignoramos el mensaje (igual logueamos un warn
  # para que el admin sepa que llegó algo de fuera).
  def process(update)
    message = update["message"] || update["edited_message"]
    return unless message

    chat_id = message.dig("chat", "id").to_s
    text    = message["text"].to_s.strip
    return if text.empty?

    user = User.find_by(telegram_chat_id: chat_id)

    unless user
      Rails.logger.warn("TelegramPollJob: chat_id=#{chat_id} no está linkeado a ningún User. Ignorando: #{text.first(40).inspect}")
      return
    end

    TelegramMessageHandler.new(user: user, chat_id: chat_id).call(text)
  rescue => e
    Rails.logger.error("TelegramPollJob#process: #{e.class} — #{e.message}")
  end
end
