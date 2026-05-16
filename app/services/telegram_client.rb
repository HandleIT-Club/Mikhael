# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
#
# Wrapper HTTP sobre la API del bot de Telegram. NO sabe nada de users —
# el caller es el que pasa el chat_id correcto.
#
# Usa Http::Client con retries automáticos (importante: la red móvil/casera
# es flaky, y un poll de Telegram que falla por timeout puntual no debería
# rebotar al usuario).
class TelegramClient
  BASE = "https://api.telegram.org".freeze

  def self.configured?
    ENV["TELEGRAM_BOT_TOKEN"].present?
  end

  # Multi-user: chat_id es obligatorio. Antes era global desde ENV; ahora
  # cada user tiene su propio telegram_chat_id y el caller lo pasa.
  def self.send_message(text, chat_id:)
    return unless configured?
    return unless chat_id.present?
    post("sendMessage", chat_id: chat_id, text: text, parse_mode: "Markdown")
  end

  def self.get_updates(offset: nil)
    params = { timeout: 1 }
    params[:offset] = offset if offset
    get("getUpdates", params)
  end

  def self.get(method, params = {})
    response = connection.get(method, params)
    parse_body(response, method)
  rescue Faraday::Error => e
    Rails.logger.error("Telegram GET #{method}: #{e.class} — #{e.message}")
    nil
  end

  def self.post(method, body)
    response = connection.post(method) do |req|
      req.headers["Content-Type"] = "application/json"
      req.body = body.to_json
    end
    parsed = parse_body(response, method)
    Rails.logger.error("Telegram POST #{method} rechazado: #{parsed.inspect} — body=#{body.inspect}") if parsed && !parsed["ok"]
    parsed
  rescue Faraday::Error => e
    Rails.logger.error("Telegram POST #{method}: #{e.class} — #{e.message}")
    nil
  end

  def self.connection
    @connection ||= Http::Client.connection(
      base_url: "#{BASE}/bot#{ENV['TELEGRAM_BOT_TOKEN']}/",
      timeout: 10,
      open_timeout: 3
    )
  end

  def self.parse_body(response, method)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.error("Telegram #{method}: respuesta no es JSON — #{e.message}")
    nil
  end

  # Cuando cambia el TELEGRAM_BOT_TOKEN (en tests o config reload) hay que
  # romper el memo.
  def self.reset_connection!
    @connection = nil
  end
end
