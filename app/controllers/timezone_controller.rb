# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Endpoint que recibe la zona detectada por el browser (Intl.DateTimeFormat)
# y la persiste vía UserTimezone. Lo llama un Stimulus controller la primera
# vez que cargás cualquier página, y solo si la zona cambió respecto a lo
# guardado.
#
# CSRF: el Stimulus controller (app/javascript/controllers/timezone_controller.js)
# manda el X-CSRF-Token del <meta>. Por eso usamos el protect_from_forgery
# normal de Rails — sin null_session, que rompía silenciosamente la sesión
# del user cuando el token faltaba.
class TimezoneController < ApplicationController
  def update
    if UserTimezone.set(params[:timezone].to_s.strip, user: current_user)
      head :no_content
    else
      render json: { error: "zona inválida" }, status: :unprocessable_entity
    end
  end
end
