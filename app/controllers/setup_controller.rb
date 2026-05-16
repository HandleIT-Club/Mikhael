# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Bootstrap del primer admin. Solo accesible cuando la DB está vacía —
# una vez que existe al menos un user, /setup redirige al login.
#
# Filosofía: Mikhael es server privado, no SaaS. Después del primer admin,
# el resto de los users los crea ese admin desde /settings. No hay signup
# público.
#
# El user creado siempre se marca admin=true (es el único que puede crear
# más users después).
#
# Dos surfaces:
#   - Browser (HTML): wizard visual + auto-login + banner one-shot del token
#   - CLI (JSON):     bin/mikhael lo usa en primer arranque. Devuelve
#                     { email, admin, api_token } y el CLI guarda el token
#                     en el .env del proyecto.
#
# CSRF: para JSON salteamos la protección (los CLIs no son browsers y no
# tienen meta tag). El endpoint solo funciona si User.count == 0 — bajo
# riesgo aunque alguien lo llame cross-origin.
class SetupController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection if: -> { request.format.json? }

  before_action :ensure_pristine!

  def new
    @user = User.new
  end

  def create
    @user = User.new(create_params.merge(admin: true))

    if @user.save
      respond_to do |format|
        format.html do
          sign_in(@user)
          redirect_to root_path,
                      notice: "¡Bienvenido, #{@user.email}!",
                      flash:  { reveal_token: @user.api_token }
        end
        format.json do
          render json: {
            email:     @user.email,
            admin:     @user.admin?,
            api_token: @user.api_token
          }, status: :created
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: { errors: @user.errors.full_messages }, status: :unprocessable_content }
      end
    end
  end

  private

  # Si ya hay al menos un user, el setup está cerrado. Redirige al login
  # con mensaje claro — sin esto, alguien podría usar /setup para crear
  # admins extra si conoce la URL.
  def ensure_pristine!
    return unless User.exists?

    respond_to do |format|
      format.html do
        redirect_to new_session_path,
                    alert: "El setup ya fue completado. Iniciá sesión con tu cuenta."
      end
      format.json do
        render json: { error: "setup_already_completed" }, status: :forbidden
      end
    end
  end

  def create_params
    params.expect(user: %i[email password telegram_chat_id])
  end
end
