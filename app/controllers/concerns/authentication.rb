# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Auth basada en sesiones cookie. Reemplaza al viejo AppAuthentication (HTTP
# Basic Auth con shared password). Cada User tiene su propio email + password.
#
# Para excluir un controller (ej: SessionsController), llamar
# `skip_before_action :authenticate_user!` y/o `allow_unauthenticated_access`.
module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :user_signed_in?
    before_action :authenticate_user!
  end

  class_methods do
    # Equivalente a Devise's allow_unauthenticated_access — skip silencioso.
    def allow_unauthenticated_access(**opts)
      skip_before_action :authenticate_user!, **opts
    end
  end

  private

  def current_user
    Current.user ||= resume_session
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    return if current_user
    store_return_location
    redirect_to new_session_path, alert: "Iniciá sesión para continuar."
  end

  def sign_in(user)
    # Preservamos return_to para no perderlo al resetear la sesión.
    return_to = session[:return_to]
    reset_session # previene session fixation
    session[:user_id]   = user.id
    session[:return_to] = return_to if return_to
    Current.user        = user
  end

  def sign_out
    reset_session
    Current.user = nil
  end

  def resume_session
    User.find_by(id: session[:user_id])
  end

  def store_return_location
    return if request.xhr? || request.format.turbo_stream?
    session[:return_to] = request.fullpath if request.get?
  end

  def consume_return_location
    session.delete(:return_to) || root_path
  end
end
