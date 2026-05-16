# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
#
# Wrapper HTTP sobre la API del bot de Telegram. NO sabe nada de users —
# el caller es el que pasa el chat_id correcto.
class TelegramClient
  BASE = "https://api.telegram.org"

  def self.configured?
    ENV["TELEGRAM_BOT_TOKEN"].present?
  end

  # Multi-user: chat_id es obligatorio. Antes era global desde ENV; ahora
  # cada user tiene su propio telegram_chat_id y el caller lo pasa.
  def self.send_message(text, chat_id:)
    return unless configured?
    return unless chat_id.present?
    post("sendMessage", { chat_id: chat_id, text: text, parse_mode: "Markdown" })
  end

  def self.get_updates(offset: nil)
    params = { timeout: 1 }
    params[:offset] = offset if offset
    get("getUpdates", params)
  end

  def self.get(method, params = {})
    uri       = URI("#{BASE}/bot#{ENV['TELEGRAM_BOT_TOKEN']}/#{method}")
    uri.query = URI.encode_www_form(params)
    res       = Net::HTTP.get_response(uri)
    JSON.parse(res.body)
  rescue => e
    Rails.logger.error("Telegram GET #{method}: #{e.message}")
    nil
  end

  def self.post(method, body)
    uri = URI("#{BASE}/bot#{ENV['TELEGRAM_BOT_TOKEN']}/#{method}")
    res = Net::HTTP.post(uri, body.to_json, "Content-Type" => "application/json")
    parsed = JSON.parse(res.body)
    unless parsed["ok"]
      Rails.logger.error("Telegram POST #{method} rechazado: #{parsed.inspect} — body=#{body.inspect}")
    end
    parsed
  rescue => e
    Rails.logger.error("Telegram POST #{method}: #{e.message}")
    nil
  end
end
