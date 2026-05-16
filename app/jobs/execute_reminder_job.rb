# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Ejecuta un Reminder en el momento programado.
#
# Multi-user: cada Reminder es de un User. La notificación va al
# telegram_chat_id de su owner. Si el user no tiene chat_id linkeado,
# logueamos un warn (no podemos avisarle).
#
# Idempotente: si executed_at ya está seteado, no hace nada.
# Tolerante a errores: un device_id inválido o un fallo de AI loguea y marca
# el reminder como ejecutado (no se reintenta indefinidamente).
class ExecuteReminderJob < ApplicationJob
  queue_as :default

  def perform(reminder_id)
    reminder = Reminder.find_by(id: reminder_id)

    unless reminder
      Rails.logger.warn("ExecuteReminderJob: reminder ##{reminder_id} no encontrado — puede haber sido borrado.")
      return
    end

    if reminder.executed_at.present?
      Rails.logger.info("ExecuteReminderJob: reminder ##{reminder_id} ya ejecutado en #{reminder.executed_at}, saltando.")
      return
    end

    execute(reminder)
    reminder.update!(executed_at: Time.current)
  rescue => e
    Rails.logger.error("ExecuteReminderJob#perform(#{reminder_id}): #{e.class} — #{e.message}")
    reminder&.update(executed_at: Time.current)
  end

  private

  def execute(reminder)
    chat_id = reminder.user.telegram_chat_id

    unless chat_id.present?
      Rails.logger.warn("ExecuteReminderJob: user ##{reminder.user_id} no tiene telegram_chat_id — no se puede notificar reminder ##{reminder.id}")
      return
    end

    case reminder.kind
    when "notify"
      TelegramClient.send_message("⏰ *Recordatorio:* #{reminder.message}", chat_id: chat_id)
    when "query_device"
      execute_device_query(reminder, chat_id)
    end
  end

  def execute_device_query(reminder, chat_id)
    device = Device.find_by(id: reminder.device_id)

    unless device
      Rails.logger.error("ExecuteReminderJob: device_id=#{reminder.device_id} no encontrado para reminder ##{reminder.id}")
      TelegramClient.send_message("⏰ ❌ No se encontró el dispositivo para el recordatorio: _#{reminder.message}_", chat_id: chat_id)
      return
    end

    result = DispatchAction.new.call(device: device, context: reminder.message, trusted: true)
    result.either(
      ->(response) {
        MqttPublisher.publish(device, response)
        msg  = "⏰ *#{device.name}* → `#{response[:action]}`"
        msg += "\nValor: #{response[:value]}" if response[:value]
        msg += "\n_#{response[:reason]}_"
        TelegramClient.send_message(msg, chat_id: chat_id)
      },
      ->(_) { TelegramClient.send_message("⏰ ❌ No se pudo consultar *#{device.name}*: _#{reminder.message}_", chat_id: chat_id) }
    )
  end
end
