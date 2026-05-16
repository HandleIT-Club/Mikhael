# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
#
# Polling de updates del bot de Telegram.
#
# Scheduling: config/recurring.yml lo ejecuta cada N segundos en producción
# (no es self-enqueuing). Si el job crashea, recurring vuelve a dispararlo
# en el siguiente tick — no hay cadena que se rompa para siempre.
#
# Concurrencia: protegido por advisory lock vía Setting/DB. Si dos workers
# disparan el job al mismo tiempo (que recurring puede hacer durante un
# rolling deploy), solo uno entra al critical section. El otro hace early
# return sin tocar el offset, evitando que ambos procesen los mismos updates
# y dupliquen mensajes.
class TelegramPollJob < ApplicationJob
  queue_as :default

  OFFSET_KEY     = "telegram_poll_offset".freeze
  LOCK_KEY       = "telegram_poll_lock".freeze
  LOCK_TTL       = 30.seconds  # mata locks de jobs colgados (worker muerto)

  def perform
    unless TelegramClient.configured?
      Rails.logger.warn("TelegramPollJob: TELEGRAM_BOT_TOKEN ausente, skip.")
      return
    end

    with_lock do
      offset   = Setting.get(OFFSET_KEY)&.to_i
      response = TelegramClient.get_updates(offset: offset)

      unless response&.dig("ok")
        Rails.logger.warn("TelegramPollJob: getUpdates devolvió #{response.inspect.truncate(200)}")
        return
      end

      updates = response["result"] || []
      return if updates.empty? # silencio cuando no hay nada — no spam logs

      Rails.logger.info("TelegramPollJob: #{updates.size} update(s) recibido(s), offset=#{offset}")
      updates.each do |update|
        process(update)
        Setting.set(OFFSET_KEY, update["update_id"] + 1)
      end
    end
  end

  private

  # Advisory lock vía Rails.cache. Atómico (write con unless_exist). Si otro
  # worker ya tiene el lock, salimos silenciosamente — el próximo tick de
  # recurring lo intentará de nuevo.
  def with_lock
    acquired = Rails.cache.write(LOCK_KEY, Process.pid.to_s, expires_in: LOCK_TTL, unless_exist: true)
    return unless acquired

    yield
  ensure
    Rails.cache.delete(LOCK_KEY) if acquired
  end

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
      Rails.logger.warn("TelegramPollJob: chat_id=#{chat_id} sin vincular. Ignorando: #{text.first(40).inspect}. " \
                       "Vinculalo desde /settings o vía bin/rails users:create con TELEGRAM_CHAT_ID=#{chat_id}.")
      return
    end

    Rails.logger.info("TelegramPollJob: procesando msg de user=#{user.id} chat=#{chat_id}: #{text.first(60).inspect}")
    TelegramMessageHandler.new(user: user, chat_id: chat_id).call(text)
  rescue => e
    Rails.logger.error("TelegramPollJob#process: #{e.class} — #{e.message}\n#{e.backtrace.first(5).join("\n")}")
  end
end
