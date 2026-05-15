require "rails_helper"

RSpec.describe "Timezone endpoint", type: :request do
  describe "PATCH /timezone" do
    it "persiste una zona válida y responde 204" do
      patch "/timezone",
            params:  { timezone: "America/Argentina/Buenos_Aires" }.to_json,
            headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:no_content)
      expect(Setting.get("user_timezone")).to eq("America/Argentina/Buenos_Aires")
    end

    it "rechaza una zona inválida con 422" do
      patch "/timezone",
            params:  { timezone: "Nada/Inventada" }.to_json,
            headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
