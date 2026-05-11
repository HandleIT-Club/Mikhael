require "rails_helper"

RSpec.describe "Api::V1::Messages", type: :request do
  let(:headers)       { { "Content-Type" => "application/json", "Accept" => "application/json" } }
  let(:conversation)  { create(:conversation) }
  let(:ai_response)   { AiResponse.new(content: "Hola!", model: "llama3.2:3b", provider: "ollama") }
  let(:mock_client)   { instance_double(Ai::OllamaClient) }

  before do
    allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
    allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
  end

  describe "POST /api/v1/conversations/:id/messages" do
    let(:url) { "/api/v1/conversations/#{conversation.id}/messages" }

    it "returns the AI response" do
      post url, params: { message: { content: "Hola" } }.to_json, headers: headers
      body = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
      expect(body["content"]).to eq("Hola!")
      expect(body["provider"]).to eq("ollama")
    end

    it "returns 422 with empty content" do
      post url, params: { message: { content: "" } }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 503 when Ollama no está disponible" do
      allow(mock_client).to receive(:chat).and_return(Dry::Monads::Failure(:ollama_unavailable))
      post url, params: { message: { content: "Hola" } }.to_json, headers: headers
      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
