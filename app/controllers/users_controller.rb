# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# CRUD de usuarios — admin-only. El listado vive en /settings (show).
#
# Reglas:
#   - Solo admin crea/edita/borra users.
#   - No te podés borrar a vos mismo (evita lockout total del sistema).
#   - No te podés quitar admin a vos mismo (mismo motivo).
#   - El API token plain solo se muestra una vez (al crear / regenerar) —
#     queda en flash para mostrar en la próxima pantalla.
class UsersController < ApplicationController
  include AdminAuthorization

  before_action :require_admin!
  before_action :set_user, only: %i[update destroy regenerate_token]

  def create
    user = User.new(create_params)

    if user.save
      redirect_to settings_path,
                  notice: "Usuario creado: #{user.email}.",
                  flash:  { reveal_token: user.api_token, reveal_user_id: user.id }
    else
      redirect_to settings_path, alert: "No se pudo crear: #{user.errors.full_messages.to_sentence}"
    end
  end

  def update
    return self_lockout!("admin") if removing_own_admin?

    if @user.update(update_params)
      redirect_to settings_path, notice: "Usuario actualizado."
    else
      redirect_to settings_path, alert: @user.errors.full_messages.to_sentence
    end
  end

  def destroy
    return self_lockout!("borrar") if @user == current_user

    @user.destroy
    redirect_to settings_path, notice: "Usuario eliminado.", status: :see_other
  end

  def regenerate_token
    plain = @user.regenerate_api_token!
    redirect_to settings_path,
                notice: "Token regenerado para #{@user.email}.",
                flash:  { reveal_token: plain, reveal_user_id: @user.id }
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def create_params
    params.expect(user: %i[email password admin telegram_chat_id])
  end

  def update_params
    # En update no permitimos cambiar password desde acá (lo hace cada user
    # via su propio flow — TODO siguiente fase). Sí dejamos toggle de admin
    # y vincular telegram_chat_id.
    params.expect(user: %i[admin telegram_chat_id])
  end

  def removing_own_admin?
    @user == current_user && update_params[:admin].in?([ "0", "false", false ])
  end

  def self_lockout!(action)
    redirect_to settings_path,
                alert: "No podés #{action} tu propio user — quedaría el sistema sin acceso."
  end
end
