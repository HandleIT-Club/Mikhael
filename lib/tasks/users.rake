# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

namespace :users do
  desc "Crear un usuario admin. Uso: bin/rails users:create EMAIL=... PASSWORD=... [TELEGRAM_CHAT_ID=...]"
  task create: :environment do
    email    = ENV["EMAIL"]    or abort("EMAIL es requerido (ej: EMAIL=admin@example.com)")
    password = ENV["PASSWORD"] or abort("PASSWORD es requerido (mínimo 12 chars)")

    user = User.create_admin!(email: email, password: password)
    user.update!(telegram_chat_id: ENV["TELEGRAM_CHAT_ID"]) if ENV["TELEGRAM_CHAT_ID"].present?

    puts "✅ Admin creado: #{user.email}"
    puts "   API token: #{user.api_token}"
    puts "   Telegram chat_id: #{user.telegram_chat_id || '(sin linkear)'}"
    puts ""
    puts "   Guardá el API token — lo necesitás para autenticar el CLI y la API."
  rescue ActiveRecord::RecordInvalid => e
    abort("❌ No se pudo crear el user: #{e.record.errors.full_messages.join(', ')}")
  end

  desc "Regenerar el API token de un user. Uso: bin/rails users:regenerate_token EMAIL=..."
  task regenerate_token: :environment do
    email = ENV["EMAIL"] or abort("EMAIL es requerido")
    user  = User.find_by(email: email.downcase.strip) or abort("Usuario no encontrado: #{email}")

    user.regenerate_api_token!
    puts "✅ Nuevo API token para #{user.email}:"
    puts "   #{user.api_token}"
  end

  desc "Listar todos los usuarios"
  task list: :environment do
    User.order(:email).each do |u|
      flags = []
      flags << "admin" if u.admin?
      flags << "tg:#{u.telegram_chat_id}" if u.telegram_chat_id.present?
      puts "#{u.email}  (#{flags.join(', ').presence || 'sin flags'})"
    end
  end
end
