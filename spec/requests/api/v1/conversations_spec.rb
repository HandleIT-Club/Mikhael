require "rails_helper"

RSpec.describe "Api::V1::Conversations", type: :request do
  let(:user)      { create(:user) }
  let(:other)     { create(:user) }
  let(:headers)   { { "Content-Type" => "application/json", "Accept" => "application/json", "Authorization" => "Bearer #{user.api_token}" } }

  before do
    allow(OllamaModels).to receive(:installed).and_return([])
  end

  describe "GET /api/v1/conversations" do
    it "returns only the current user's conversations" do
      create_list(:conversation, 3, user: user)
      create_list(:conversation, 2, user: other)
      get "/api/v1/conversations", headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(3)
    end

    it "rechaza requests sin Bearer token" do
      get "/api/v1/conversations", headers: headers.except("Authorization")
      expect(response).to have_http_status(:unauthorized)
    end

    it "rechaza requests con token inválido" do
      get "/api/v1/conversations", headers: headers.merge("Authorization" => "Bearer falso")
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/conversations/:id" do
    let(:conversation) { create(:conversation, user: user) }

    it "returns the conversation with messages" do
      create(:message, conversation: conversation)
      get "/api/v1/conversations/#{conversation.id}", headers: headers
      body = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(body["messages"].length).to eq(1)
    end

    it "404 si el id pertenece a otro user (scoping)" do
      other_conv = create(:conversation, user: other)
      get "/api/v1/conversations/#{other_conv.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for unknown id" do
      get "/api/v1/conversations/0", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/conversations" do
    let(:valid_params) { { conversation: { title: "Test", model_id: "llama-3.3-70b-versatile" } } }

    it "creates a conversation owned by the current user" do
      expect {
        post "/api/v1/conversations", params: valid_params.to_json, headers: headers
      }.to change(user.conversations, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "returns error with invalid provider" do
      params = { conversation: { title: "Test", provider: "invalid", model_id: "x" } }
      post "/api/v1/conversations", params: params.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/v1/conversations/:id" do
    it "no permite borrar una conversación de otro user" do
      other_conv = create(:conversation, user: other)
      delete "/api/v1/conversations/#{other_conv.id}", headers: headers
      expect(response).to have_http_status(:not_found)
      expect(Conversation.exists?(other_conv.id)).to be(true)
    end
  end
end
