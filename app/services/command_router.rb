# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Maneja slash commands (/zona, /recordatorios, /dispositivos, /borrar_recordatorio,
# /reset, /resumir, /start) de forma uniforme entre web y Telegram. Devuelve nil si el
# texto no es un comando — el caller sigue al flujo normal (intent router → AI).
#
# Scoping: los comandos que tocan recursos per-user (recordatorios, zona)
# operan sobre el `user` pasado al constructor. Los que tocan recursos
# compartidos (dispositivos) son globales.
class CommandRouter
  Result = Data.define(:reply) do
    def self.message(text) = new(reply: text)
  end

  def self.handle(text, user:, conversation: nil)
    new(text.to_s.strip, user: user, conversation: conversation).handle
  end

  def initialize(text, user:, conversation: nil)
    @text         = text
    @user         = user
    @conversation = conversation
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
    when "/reset"           then Result.message("✅ Conversación reiniciada.")
    when "/resumir"         then summarize_conversation
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
      "`/resumir` — guardar un resumen de la conversación actual\n" \
      "`/reset` — empezar de cero"
    )
  end

  def summarize_conversation
    unless @conversation
      return Result.message("❌ No hay conversación activa para resumir.")
    end

    if @conversation.chat_messages.count < 2
      return Result.message("❌ La conversación es muy corta para resumir.")
    end

    GenerateMemoryJob.perform_now(@conversation.id)
    Result.message("✅ Resumen guardado en memorias.")
  end

  # Dispositivos son compartidos (decisión de arquitectura: hogar).
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

  # Recordatorios sí son per-user.
  def list_reminders
    return Result.message("Iniciá sesión para ver tus recordatorios.") unless @user

    reminders = @user.reminders.upcoming.limit(10)
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
    return Result.message("Iniciá sesión para gestionar tus recordatorios.") unless @user

    # Solo dejamos borrar reminders del user actual.
    reminder = @user.reminders.find_by(id: id)

    return Result.message("❌ No existe el recordatorio ##{id}.") if reminder.nil?
    return Result.message("❌ El recordatorio ##{id} ya fue ejecutado y no se puede cancelar.") if reminder.executed_at.present?

    reminder.destroy!
    Result.message("✅ Recordatorio ##{id} cancelado.")
  end

  # Zona horaria sí es per-user — cada uno la suya.
  def set_timezone(name)
    return Result.message("Iniciá sesión para configurar tu zona.") unless @user

    if UserTimezone.set(name, user: @user)
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
    tz = UserTimezone.current(user: @user)
    source =
      if @user && Setting.get_for(@user, UserTimezone::SETTING_KEY).present?
        "guardada en tu cuenta"
      elsif ENV["MIKHAEL_TZ"].present?
        "del ENV MIKHAEL_TZ"
      else
        "por defecto (UTC)"
      end
    Result.message("Zona actual: *#{tz}* (#{source}).\nCambiala con `/zona <nombre>`.")
  end
end
