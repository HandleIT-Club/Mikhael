# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Maneja comandos slash (/zona, /recordatorios, /dispositivos, etc.) de forma
# uniforme entre superficies. Devuelve nil si el texto no es un comando — el
# caller sigue al flujo normal (intent router → AI).
#
# Antes estos comandos solo existían en TelegramMessageHandler; ahora también
# corren en web.
class CommandRouter
  Result = Data.define(:reply) do
    def self.message(text) = new(reply: text)
  end

  def self.handle(text)
    new(text.to_s.strip).handle
  end

  def initialize(text)
    @text = text
  end

  def handle
    case @text
    when "/start"           then start_help
    when "/dispositivos"    then list_devices
    when "/recordatorios"   then list_reminders
    when "/zona"            then show_current_zone
    when /\A\/zona\s+(.+)\z/i
      set_timezone(Regexp.last_match(1).strip)
    when /\A\/borrar_recordatorio\s+(\d+)\z/
      delete_reminder(Regexp.last_match(1).to_i)
    when "/reset"           then Result.message("✅ Conversación reiniciada.")  # reset real lo hace el caller
    else nil
    end
  end

  def reset_command? = @text == "/reset"

  private

  def start_help
    Result.message(
      "👋 Soy *Mikhael*. Conozco tus dispositivos, los puedo comandar y puedo programarte recordatorios.\n\n" \
      "Comandos:\n" \
      "`/dispositivos` — listar devices\n" \
      "`/recordatorios` — ver recordatorios pendientes\n" \
      "`/borrar_recordatorio <id>` — cancelar un recordatorio\n" \
      "`/zona <nombre>` — configurar zona horaria (ej: `/zona Buenos Aires`)\n" \
      "`/zona` — ver zona actual\n" \
      "`/reset` — empezar de cero"
    )
  end

  def list_devices
    devices = Device.order(:name)
    return Result.message("No hay dispositivos registrados.") if devices.empty?

    lines = devices.map do |d|
      status  = d.online? ? "🟢" : "🔴"
      actions = d.actions_list.any? ? " · `#{d.actions_list.join(', ')}`" : ""
      "#{status} *#{d.name}* (`#{d.device_id}`)#{actions}"
    end
    Result.message("*Dispositivos:*\n#{lines.join("\n")}")
  end

  def list_reminders
    reminders = Reminder.upcoming.limit(10)
    return Result.message("No hay recordatorios pendientes.") if reminders.empty?

    tz = UserTimezone.current
    lines = reminders.map do |r|
      formatted = r.scheduled_for.in_time_zone(tz).strftime("%d/%m %H:%M")
      kind_tag  = r.query_device? ? " 📡" : ""
      "[#{r.id}] #{formatted}#{kind_tag} — #{r.message}"
    end
    Result.message("📋 *Recordatorios pendientes:*\n#{lines.join("\n")}\n\n_Usá /borrar\\_recordatorio <id> para cancelar uno._")
  end

  def delete_reminder(id)
    reminder = Reminder.find_by(id: id)

    return Result.message("❌ No existe el recordatorio ##{id}.") if reminder.nil?
    return Result.message("❌ El recordatorio ##{id} ya fue ejecutado y no se puede cancelar.") if reminder.executed_at.present?

    reminder.destroy!
    Result.message("✅ Recordatorio ##{id} cancelado.")
  end

  def set_timezone(name)
    if UserTimezone.set(name)
      Result.message("✅ Zona horaria configurada: *#{name}*. Probá ahora: \"qué hora es\".")
    else
      Result.message(
        "❌ Zona desconocida: «#{name}».\n\n" \
        "Probá con un nombre amigable (`Buenos Aires`, `Madrid`, `Mexico City`, `Bogota`) " \
        "o el nombre IANA completo (`America/New_York`, `Europe/London`)."
      )
    end
  end

  def show_current_zone
    tz = UserTimezone.current
    source =
      if Setting.get(UserTimezone::SETTING_KEY).present?
        "guardada en la app"
      elsif ENV["MIKHAEL_TZ"].present?
        "del ENV MIKHAEL_TZ"
      else
        "por defecto (UTC)"
      end
    Result.message("Zona actual: *#{tz}* (#{source}).\nCambiala con `/zona <nombre>`.")
  end
end
