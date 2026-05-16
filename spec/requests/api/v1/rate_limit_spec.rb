require "rails_helper"

# Estrategia: pre-cargamos el contador del rate limit al valor máximo usando
# RATE_LIMIT_STORE.write con la cache key que usa Rails 8. Una sola request
# real posterior dispara el 429 sin necesitar N requests reales.
#
# Multi-user: el by: del rate limit ahora es "u:<user_id>" cuando hay auth,
# "ip:<remote_ip>" cuando no. Las API que tienen auth de User usan u:; el
# endpoint /api/v1/action sigue usando el token del Device.

RSpec.describe "Rate Limiting", type: :request do
  let(:json_headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }

  # ─────────────────────────────────────────────────────────────────────────────
  # POST /api/v1/action — por token de dispositivo (no User)
  # ─────────────────────────────────────────────────────────────────────────────
  describe "POST /api/v1/action" do
    let(:device)       { create(:device) }
    let(:other_device) { create(:device) }
    let(:limit)        { ENV.fetch("RATE_LIMIT_ACTION_PER_MIN", "60").to_i }
    let(:auth_headers) { json_headers.merge("Authorization" => "Bearer #{device.token}") }

    def action_cache_key(token) = "rate-limit:api/v1/actions:#{token}"
    def seed_limit(token) = RATE_LIMIT_STORE.write(action_cache_key(token), limit, expires_in: 1.minute)

    it "devuelve 429 al superar el límite" do
      seed_limit(device.token)
      post "/api/v1/action", params: { context: "test" }.to_json, headers: auth_headers
      expect(response).to have_http_status(:too_many_requests)
    end

    it "Retry-After + body con error" do
      seed_limit(device.token)
      post "/api/v1/action", params: { context: "test" }.to_json, headers: auth_headers
      expect(response.headers["Retry-After"]).to eq("30")
      expect(JSON.parse(response.body)).to include("error" => "rate_limit_exceeded")
    end

    it "contadores independientes por token de device" do
      seed_limit(device.token)
      mock_client = instance_double(Ai::RubyLlmClient)
      allow(OllamaModels).to receive(:installed).and_return([])
      allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
      allow(mock_client).to receive(:chat).and_return(
        Dry::Monads::Success(AiResponse.new(content: '{"action":"x","reason":"y"}', model: "m", provider: "p"))
      )
      allow(TelegramClient).to receive(:send_message)
      other_headers = json_headers.merge("Authorization" => "Bearer #{other_device.token}")
      post "/api/v1/action", params: { context: "test" }.to_json, headers: other_headers
      expect(response).not_to have_http_status(:too_many_requests)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # POST /api/v1/conversations/:id/messages — por User (Bearer api_token)
  # ─────────────────────────────────────────────────────────────────────────────
  describe "POST /api/v1/conversations/:id/messages" do
    let(:user)         { create(:user) }
    let(:conversation) { create(:conversation, user: user) }
    let(:limit)        { ENV.fetch("RATE_LIMIT_MESSAGES_PER_MIN", "30").to_i }
    let(:headers)      { json_headers.merge("Authorization" => "Bearer #{user.api_token}") }

    def cache_key(user) = "rate-limit:api/v1/messages:u:#{user.id}"

    before { RATE_LIMIT_STORE.write(cache_key(user), limit, expires_in: 1.minute) }

    it "devuelve 429" do
      post "/api/v1/conversations/#{conversation.id}/messages",
           params: { message: { content: "hola" } }.to_json, headers: headers
      expect(response).to have_http_status(:too_many_requests)
    end

    it "Retry-After + body" do
      post "/api/v1/conversations/#{conversation.id}/messages",
           params: { message: { content: "hola" } }.to_json, headers: headers
      expect(response.headers["Retry-After"]).to eq("30")
      expect(JSON.parse(response.body)).to include("error" => "rate_limit_exceeded")
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Rutas web (logged in) — por user_id
  # ─────────────────────────────────────────────────────────────────────────────
  describe "Rutas web logueado" do
    let(:user)  { create(:user) }
    let(:limit) { ENV.fetch("RATE_LIMIT_WEB_PER_MIN", "100").to_i }

    before do
      sign_in_as(user)
      RATE_LIMIT_STORE.write("rate-limit:conversations:web:u:#{user.id}", limit, expires_in: 1.minute)
    end

    it "devuelve 429 en GET / al superar el límite" do
      get "/"
      expect(response).to have_http_status(:too_many_requests)
    end

    it "el body incluye error y retry_after" do
      get "/"
      expect(JSON.parse(response.body)).to include("error" => "rate_limit_exceeded", "retry_after" => 30)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Login — protección contra brute force
  # ─────────────────────────────────────────────────────────────────────────────
  describe "POST /session (login)" do
    let(:limit) { ENV.fetch("RATE_LIMIT_LOGIN_PER_MIN", "5").to_i }

    it "después de N intentos fallidos rechaza con 429" do
      ip_key = "rate-limit:sessions:login:#{::IPAddr.new('127.0.0.1')&.to_s}"
      # Más simple: directamente seedear con la key que usamos
      RATE_LIMIT_STORE.write("rate-limit:sessions:login:127.0.0.1", limit, expires_in: 1.minute)

      post session_path, params: { email: "alguien@example.com", password: "wrongpass" }
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
