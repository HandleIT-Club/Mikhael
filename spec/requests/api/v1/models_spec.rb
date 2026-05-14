require "rails_helper"

RSpec.describe "Api::V1::Models", type: :request do
  let(:headers) { { "Accept" => "application/json" } }

  before do
    allow(OllamaModels).to receive(:installed).and_return([])
  end

  describe "GET /api/v1/models" do
    it "devuelve lista de modelos disponibles" do
      get "/api/v1/models", headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body).not_to be_empty
    end

    it "cada modelo tiene model_id y provider" do
      get "/api/v1/models", headers: headers
      body = JSON.parse(response.body)
      body.each do |m|
        expect(m).to have_key("model_id")
        expect(m).to have_key("provider")
      end
    end

    it "incluye modelos de groq" do
      get "/api/v1/models", headers: headers
      body = JSON.parse(response.body)
      providers = body.map { |m| m["provider"] }.uniq
      expect(providers).to include("groq")
    end

    it "incluye modelos de ollama si están instalados" do
      allow(OllamaModels).to receive(:installed).and_return([ "llama3.2:3b" ])
      get "/api/v1/models", headers: headers
      body = JSON.parse(response.body)
      ollama = body.select { |m| m["provider"] == "ollama" }
      expect(ollama.map { |m| m["model_id"] }).to include("llama3.2:3b")
    end
  end
end
