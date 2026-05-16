# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Restringe acciones a users con admin=true.
#
# Filosofía: Mikhael es asistente personal/familiar. Hay recursos que NO son
# per-user — devices del hogar, configs de modelos — y un familiar invitado
# no debería poder borrar la cerradura ni regenerar tokens. Esta concern
# resuelve eso de forma uniforme.
#
# Web: redirige al root con alert.
# API: devuelve 403 JSON.
module AdminAuthorization
  extend ActiveSupport::Concern

  private

  def require_admin!
    return if current_user&.admin?

    respond_to do |format|
      format.json { render json: { error: "forbidden" }, status: :forbidden }
      format.any  { redirect_to root_path, alert: "Solo los administradores pueden acceder a esa sección." }
    end
  end
end
