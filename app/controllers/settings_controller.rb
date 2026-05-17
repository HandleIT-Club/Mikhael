# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Settings page (admin-only). Una sola pantalla con dos secciones:
#   - Contexto general (el "preamble" del asistente)
#   - Cuentas (gestión de users)
#
# Devices vive aparte en /devices porque es la "feature estrella" — la
# entrada a la robótica/IoT. Mezclar sería diluir.
class SettingsController < ApplicationController
  include AdminAuthorization

  before_action :require_admin!

  def show
    @preamble  = AssistantContext.preamble
    @language  = AssistantContext.language
    @users     = User.order(:email)
    @new_user  = User.new
  end

  def update
    AssistantContext.set_preamble(preamble_param)
    AssistantContext.set_language(language_param) if language_param.present?
    redirect_to settings_path, notice: "Contexto del asistente actualizado."
  end

  private

  def preamble_param
    params.require(:settings).fetch(:assistant_preamble, "").to_s
  end

  def language_param
    params.require(:settings).fetch(:assistant_language, "").to_s
  end
end
