# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class TelegramClient
  BASE    = "https://api.telegram.org"
  CHAT_ID = ENV["TELEGRAM_CHAT_ID"]

  def self.configured?
    ENV["TELEGRAM_BOT_TOKEN"].present? && CHAT_ID.present?
  end

  def self.send_message(text)
    return unless configured?
    post("sendMessage", { chat_id: CHAT_ID, text: text, parse_mode: "Markdown" })
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
    # Telegram devuelve 200 OK pero {"ok": false, "description": "..."} cuando
    # rechaza el contenido (ej: Markdown mal parseado por un "_" suelto). Sin
    # este log el error es silencioso y la respuesta nunca llega al usuario.
    unless parsed["ok"]
      Rails.logger.error("Telegram POST #{method} rechazado: #{parsed.inspect} — body=#{body.inspect}")
    end
    parsed
  rescue => e
    Rails.logger.error("Telegram POST #{method}: #{e.message}")
    nil
  end
end
