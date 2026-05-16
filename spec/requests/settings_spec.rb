require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:admin)     { create(:user, :admin) }
  let(:non_admin) { create(:user) }

  describe "GET /settings" do
    context "como admin" do
      before { sign_in_as(admin) }

      it "responde 200 y muestra el preamble actual" do
        get settings_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Contexto del asistente")
        expect(response.body).to include(AssistantContext::DEFAULT_PREAMBLE.first(40))
      end

      it "muestra la sección de cuentas con todos los users" do
        other = create(:user, email: "otro@example.test")
        get settings_path
        expect(response.body).to include(admin.email)
        expect(response.body).to include(other.email)
      end
    end

    context "como user no-admin" do
      before { sign_in_as(non_admin) }

      it "redirige al root con alert" do
        get settings_path
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("administradores")
      end
    end

    context "sin sesión" do
      it "redirige al login" do
        get settings_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "PATCH /settings" do
    before { sign_in_as(admin) }

    it "actualiza el preamble y persiste" do
      patch settings_path, params: { settings: { assistant_preamble: "Sos Mikhael, asistente custom." } }
      expect(response).to redirect_to(settings_path)
      expect(AssistantContext.preamble).to eq("Sos Mikhael, asistente custom.")
    end

    it "vacío restaura el default" do
      AssistantContext.set_preamble("custom")
      patch settings_path, params: { settings: { assistant_preamble: "" } }
      expect(AssistantContext.preamble).to eq(AssistantContext::DEFAULT_PREAMBLE)
    end

    it "no-admin no puede actualizar (403/redirect)" do
      sign_in_as(non_admin)
      patch settings_path, params: { settings: { assistant_preamble: "hack" } }
      expect(response).to redirect_to(root_path)
    end
  end
end
