# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Login (new/create) + logout (destroy). Sin signup público — el primer
# admin se crea desde /setup (o `bin/rails users:create` por CLI), los
# siguientes los crea ese admin desde /settings. Mikhael es asistente
# personal/familiar, no SaaS.
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  # Brute force: un usuario puede tener un user enumeration attack si
  # respondemos diferente entre "email no existe" y "password mal". Por eso
  # el mensaje de error es genérico. Y el rate limiter está acá abajo.
  rate_limit to:     ENV.fetch("RATE_LIMIT_LOGIN_PER_MIN", "5").to_i,
             within: 1.minute,
             by:     -> { "login:#{request.remote_ip}" },
             with:   -> { render_login_rate_limited },
             store:  RATE_LIMIT_STORE,
             only:   :create

  def new
    return redirect_to root_path if user_signed_in?
    # DB vacía → no hay con quién loguearse. Mandamos al wizard de setup
    # para que el primer admin pueda crearse desde el browser.
    redirect_to setup_path unless User.exists?
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password])
      sign_in(user)
      Rails.logger.info("Login OK — user=#{user.id}")
      redirect_to consume_return_location, notice: "¡Hola, #{user.email}!"
    else
      Rails.logger.warn("Login fallido — email=#{params[:email].to_s.first(20)} ip=#{request.remote_ip}")
      flash.now[:alert] = "Email o contraseña incorrectos."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    sign_out
    redirect_to new_session_path, notice: "Sesión cerrada."
  end

  private

  def render_login_rate_limited
    Rails.logger.warn("[RateLimit] login bloqueado para ip=#{request.remote_ip}")
    flash.now[:alert] = "Demasiados intentos de login. Esperá un minuto."
    render :new, status: :too_many_requests
  end
end
