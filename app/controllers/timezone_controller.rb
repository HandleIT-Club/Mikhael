# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Endpoint que recibe la zona detectada por el browser (Intl.DateTimeFormat)
# y la persiste vía UserTimezone. Lo llama un Stimulus controller la primera
# vez que cargás cualquier página, y solo si la zona cambió respecto a lo
# guardado.
class TimezoneController < ApplicationController
  protect_from_forgery with: :null_session

  def update
    tz = params[:timezone].to_s.strip

    if UserTimezone.set(tz)
      head :no_content
    else
      render json: { error: "zona inválida: #{tz}" }, status: :unprocessable_entity
    end
  end
end
