require "rails_helper"

RSpec.describe "Timezone endpoint", type: :request do
  let(:user) { create(:user) }
  before    { sign_in_as(user) }

  describe "PATCH /timezone" do
    it "persiste una zona válida para el current user y responde 204" do
      patch "/timezone",
            params:  { timezone: "America/Argentina/Buenos_Aires" }.to_json,
            headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:no_content)
      expect(Setting.get_for(user, "user_timezone")).to eq("America/Argentina/Buenos_Aires")
    end

    it "rechaza una zona inválida con 422" do
      patch "/timezone",
            params:  { timezone: "Nada/Inventada" }.to_json,
            headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /timezone sin login" do
    it "redirige al login (no procesa el cambio)" do
      reset!  # cierra la sesión
      patch "/timezone",
            params:  { timezone: "Madrid" }.to_json,
            headers: { "Content-Type" => "application/json" }
      expect(response).to redirect_to(new_session_path)
    end
  end
end
