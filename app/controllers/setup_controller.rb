# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Bootstrap del primer admin desde el browser. Solo accesible cuando la DB
# está vacía — una vez que existe al menos un user, /setup redirige al login.
#
# Filosofía: Mikhael es server privado, no SaaS. Después del primer admin,
# el resto de los users los crea ese admin desde /settings. No hay signup
# público.
#
# El user creado siempre se marca admin=true (es el único que puede crear
# más users después).
class SetupController < ApplicationController
  allow_unauthenticated_access

  before_action :ensure_pristine!

  def new
    @user = User.new
  end

  def create
    @user = User.new(create_params.merge(admin: true))

    if @user.save
      sign_in(@user)
      redirect_to root_path,
                  notice: "¡Bienvenido, #{@user.email}!",
                  flash:  { reveal_token: @user.api_token }
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  # Si ya hay al menos un user, el setup está cerrado. Redirige al login
  # con mensaje claro — sin esto, alguien podría usar /setup para crear
  # admins extra si conoce la URL.
  def ensure_pristine!
    return unless User.exists?
    redirect_to new_session_path,
                alert: "El setup ya fue completado. Iniciá sesión con tu cuenta."
  end

  def create_params
    params.expect(user: %i[email password telegram_chat_id])
  end
end
