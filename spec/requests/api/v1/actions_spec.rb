require "rails_helper"

RSpec.describe "Api::V1::Actions", type: :request do
  let(:headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }
  let(:device)  { create(:device) }
  let(:auth)    { { "Authorization" => "Bearer #{device.token}" } }

  let(:ai_response) do
    AiResponse.new(
      content:  '{"action":"open_valve","value":30,"reason":"humedad baja"}',
      model:    "llama-3.3-70b-versatile",
      provider: "groq"
    )
  end
  let(:mock_client) { instance_double(Ai::RubyLlmClient) }

  before do
    allow(OllamaModels).to receive(:installed).and_return([])
    stub_ai_provider!
    allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
    allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
  end

  describe "POST /api/v1/action" do
    context "con token válido" do
      it "usa #chat (nunca #stream) — DispatchAction no hace streaming" do
        allow(mock_client).to receive(:stream)
        post "/api/v1/action",
             params: { context: "humedad: 20%" }.to_json,
             headers: headers.merge(auth)
        expect(mock_client).to have_received(:chat)
        expect(mock_client).not_to have_received(:stream)
      end

      it "devuelve la acción estructurada" do
        post "/api/v1/action",
             params: { context: "humedad: 20%" }.to_json,
             headers: headers.merge(auth)
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to have_key("action")
        expect(body).to have_key("reason")
        expect(body["action"]).to eq("open_valve")
      end

      it "no incluye requires_confirmation para dispositivo normal" do
        post "/api/v1/action",
             params: { context: "humedad: 20%" }.to_json,
             headers: headers.merge(auth)
        body = JSON.parse(response.body)
        expect(body["requires_confirmation"]).to be_nil
      end

      it "incluye requires_confirmation para dispositivo de alta seguridad" do
        high_device = create(:device, :high_security)
        post "/api/v1/action",
             params: { context: "abrir cerradura" }.to_json,
             headers: headers.merge("Authorization" => "Bearer #{high_device.token}")
        body = JSON.parse(response.body)
        expect(body["requires_confirmation"]).to be true
      end
    end

    context "con token inválido" do
      it "retorna 401" do
        post "/api/v1/action",
             params: { context: "test" }.to_json,
             headers: headers.merge("Authorization" => "Bearer token_falso")
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "sin context" do
      it "retorna 422" do
        post "/api/v1/action",
             params: { context: "" }.to_json,
             headers: headers.merge(auth)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
