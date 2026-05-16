require "rails_helper"

RSpec.describe "Api::V1::Messages", type: :request do
  let(:user)          { create(:user) }
  let(:headers)       { { "Content-Type" => "application/json", "Accept" => "application/json", "Authorization" => "Bearer #{user.api_token}" } }
  let(:conversation)  { create(:conversation, user: user) }
  let(:ai_response)   { AiResponse.new(content: "Hola!", model: "llama-3.3-70b-versatile", provider: "groq") }
  let(:mock_client)   { instance_double(Ai::RubyLlmClient) }

  before do
    allow(OllamaModels).to receive(:installed).and_return([])
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
      expect(body["provider"]).to eq("groq")
    end

    it "returns 422 with empty content" do
      post url, params: { message: { content: "" } }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 503 when AI no está disponible" do
      allow(mock_client).to receive(:chat).and_return(Dry::Monads::Failure(:ollama_unavailable))
      post url, params: { message: { content: "Hola" } }.to_json, headers: headers
      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
