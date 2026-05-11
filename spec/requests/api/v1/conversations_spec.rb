require "rails_helper"

RSpec.describe "Api::V1::Conversations", type: :request do
  let(:headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }

  describe "GET /api/v1/conversations" do
    it "returns all conversations" do
      create_list(:conversation, 3)
      get "/api/v1/conversations", headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(3)
    end
  end

  describe "GET /api/v1/conversations/:id" do
    let(:conversation) { create(:conversation) }

    it "returns the conversation with messages" do
      create(:message, conversation: conversation)
      get "/api/v1/conversations/#{conversation.id}", headers: headers
      body = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(body["messages"].length).to eq(1)
    end

    it "returns 404 for unknown id" do
      get "/api/v1/conversations/0", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/conversations" do
    let(:valid_params) { { conversation: { title: "Test", provider: "ollama", model_id: "llama3.2:3b" } } }

    it "creates a conversation" do
      expect {
        post "/api/v1/conversations", params: valid_params.to_json, headers: headers
      }.to change(Conversation, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "returns error with invalid provider" do
      params = { conversation: { title: "Test", provider: "invalid", model_id: "x" } }
      post "/api/v1/conversations", params: params.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
