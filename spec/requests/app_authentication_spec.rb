require "rails_helper"

RSpec.describe "AppAuthentication (MIKHAEL_PASSWORD)", type: :request do
  before { allow(OllamaModels).to receive(:installed).and_return([]) }

  context "sin MIKHAEL_PASSWORD configurado" do
    before { ENV.delete("MIKHAEL_PASSWORD") }

    it "permite acceso libre a /api/v1/conversations" do
      get "/api/v1/conversations"
      expect(response).to have_http_status(:ok)
    end

    it "permite acceso libre a /api/v1/devices" do
      get "/api/v1/devices"
      expect(response).to have_http_status(:ok)
    end
  end

  context "con MIKHAEL_PASSWORD configurado" do
    let(:password) { "secret123" }

    before { ENV["MIKHAEL_PASSWORD"] = password }
    after  { ENV.delete("MIKHAEL_PASSWORD") }

    it "rechaza /api/v1/conversations sin credenciales" do
      get "/api/v1/conversations"
      expect(response).to have_http_status(:unauthorized)
    end

    it "rechaza /api/v1/devices con password incorrecto" do
      get "/api/v1/devices", headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("mikhael", "wrong") }
      expect(response).to have_http_status(:unauthorized)
    end

    it "permite /api/v1/conversations con credenciales correctas" do
      get "/api/v1/conversations", headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("mikhael", password) }
      expect(response).to have_http_status(:ok)
    end

    it "no exige basic auth en /api/v1/action (queda solo con auth por token)" do
      device = create(:device)
      post "/api/v1/action",
           params: { context: "" }.to_json,
           headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{device.token}" }
      expect(response).not_to have_http_status(:unauthorized)
    end
  end
end
