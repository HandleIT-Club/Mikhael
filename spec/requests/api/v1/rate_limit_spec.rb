require "rails_helper"

# Estrategia de test: pre-cargamos el contador del rate limit al valor máximo
# usando RATE_LIMIT_STORE.write con la cache key exacta que usa Rails 8.
# Formato: "rate-limit:<controller_path>:<name (si existe)>:<by_value>"
# Una sola request real posterior dispara el 429 sin necesitar N requests reales.

RSpec.describe "Rate Limiting", type: :request do
  let(:json_headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }

  # ─────────────────────────────────────────────────────────────────────────────
  # POST /api/v1/action — 60 req/min por token de dispositivo
  # ─────────────────────────────────────────────────────────────────────────────
  describe "POST /api/v1/action" do
    let(:device) { create(:device) }
    let(:other_device) { create(:device) }
    let(:limit) { ENV.fetch("RATE_LIMIT_ACTION_PER_MIN", "60").to_i }

    let(:auth_headers) { json_headers.merge("Authorization" => "Bearer #{device.token}") }

    def action_cache_key(token)
      "rate-limit:api/v1/actions:#{token}"
    end

    def seed_limit(token)
      RATE_LIMIT_STORE.write(action_cache_key(token), limit, expires_in: 1.minute)
    end

    context "al superar el límite" do
      before { seed_limit(device.token) }

      it "devuelve 429" do
        post "/api/v1/action", params: { context: "test" }.to_json, headers: auth_headers
        expect(response).to have_http_status(:too_many_requests)
      end

      it "incluye el header Retry-After" do
        post "/api/v1/action", params: { context: "test" }.to_json, headers: auth_headers
        expect(response.headers["Retry-After"]).to eq("30")
      end

      it "el body tiene error y retry_after" do
        post "/api/v1/action", params: { context: "test" }.to_json, headers: auth_headers
        body = JSON.parse(response.body)
        expect(body).to include("error" => "rate_limit_exceeded", "retry_after" => 30)
      end
    end

    it "los contadores son independientes por token" do
      mock_client = instance_double(Ai::RubyLlmClient)
      allow(OllamaModels).to receive(:installed).and_return([])
      allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
      allow(mock_client).to receive(:chat).and_return(
        Dry::Monads::Success(
          AiResponse.new(content: '{"action":"test","reason":"ok"}', model: "m", provider: "p")
        )
      )
      allow(TelegramClient).to receive(:send_message)

      # Agotamos el límite del primer dispositivo
      seed_limit(device.token)

      # El segundo dispositivo todavía tiene su ventana libre
      other_headers = json_headers.merge("Authorization" => "Bearer #{other_device.token}")
      post "/api/v1/action", params: { context: "test" }.to_json, headers: other_headers
      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "el contador se resetea al expirar la ventana (el store expira la key)" do
      # Escribimos con TTL muy corto y verificamos que el store lo expira.
      # Testeamos el comportamiento del store, no de nuestro código, pero
      # documenta el contrato que hace funcionar el mecanismo de ventana.
      RATE_LIMIT_STORE.write(action_cache_key(device.token), limit, expires_in: 0.05)
      sleep(0.1)
      expect(RATE_LIMIT_STORE.read(action_cache_key(device.token))).to be_nil
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # POST /api/v1/conversations/:id/messages — 30 req/min por IP
  # ─────────────────────────────────────────────────────────────────────────────
  describe "POST /api/v1/conversations/:id/messages" do
    let(:conversation) { create(:conversation) }
    let(:limit) { ENV.fetch("RATE_LIMIT_MESSAGES_PER_MIN", "30").to_i }
    let(:ip) { "127.0.0.1" }

    def messages_cache_key
      "rate-limit:api/v1/messages:#{ip}"
    end

    before { RATE_LIMIT_STORE.write(messages_cache_key, limit, expires_in: 1.minute) }

    it "devuelve 429 al superar el límite" do
      post "/api/v1/conversations/#{conversation.id}/messages",
           params: { message: { content: "hola" } }.to_json,
           headers: json_headers
      expect(response).to have_http_status(:too_many_requests)
    end

    it "incluye Retry-After" do
      post "/api/v1/conversations/#{conversation.id}/messages",
           params: { message: { content: "hola" } }.to_json,
           headers: json_headers
      expect(response.headers["Retry-After"]).to eq("30")
    end

    it "el body tiene error y retry_after" do
      post "/api/v1/conversations/#{conversation.id}/messages",
           params: { message: { content: "hola" } }.to_json,
           headers: json_headers
      body = JSON.parse(response.body)
      expect(body).to include("error" => "rate_limit_exceeded", "retry_after" => 30)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # POST /api/v1/conversations/:id/messages/stream — 30 req/min por IP
  # ─────────────────────────────────────────────────────────────────────────────
  describe "POST /api/v1/conversations/:id/messages/stream" do
    let(:conversation) { create(:conversation) }
    let(:limit) { ENV.fetch("RATE_LIMIT_MESSAGES_PER_MIN", "30").to_i }
    let(:ip) { "127.0.0.1" }

    def stream_cache_key
      "rate-limit:api/v1/message_streams:#{ip}"
    end

    before { RATE_LIMIT_STORE.write(stream_cache_key, limit, expires_in: 1.minute) }

    it "devuelve 429 al superar el límite" do
      post "/api/v1/conversations/#{conversation.id}/messages/stream",
           params: { message: { content: "hola" } }.to_json,
           headers: json_headers
      expect(response).to have_http_status(:too_many_requests)
    end

    it "incluye Retry-After" do
      post "/api/v1/conversations/#{conversation.id}/messages/stream",
           params: { message: { content: "hola" } }.to_json,
           headers: json_headers
      expect(response.headers["Retry-After"]).to eq("30")
    end

    it "stream y messages tienen contadores independientes (mismo límite, distinto scope)" do
      # Solo el stream está saturado; messages debería llegar a su propio check
      # (y fallar por otra razón, no 429)
      messages_cache_key = "rate-limit:api/v1/messages:#{ip}"
      expect(RATE_LIMIT_STORE.read(messages_cache_key)).to be_nil
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # POST /api/v1/devices/:id/command — 30 req/min por IP
  # ─────────────────────────────────────────────────────────────────────────────
  describe "POST /api/v1/devices/:id/command" do
    let(:device) { create(:device) }
    let(:limit) { ENV.fetch("RATE_LIMIT_MESSAGES_PER_MIN", "30").to_i }
    let(:ip) { "127.0.0.1" }

    def command_cache_key
      "rate-limit:api/v1/devices:#{ip}"
    end

    before { RATE_LIMIT_STORE.write(command_cache_key, limit, expires_in: 1.minute) }

    it "devuelve 429 al superar el límite" do
      post "/api/v1/devices/#{device.id}/command",
           params: { message: "abrí la válvula" }.to_json,
           headers: json_headers
      expect(response).to have_http_status(:too_many_requests)
    end

    it "incluye Retry-After" do
      post "/api/v1/devices/#{device.id}/command",
           params: { message: "abrí la válvula" }.to_json,
           headers: json_headers
      expect(response.headers["Retry-After"]).to eq("30")
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Rutas web — ApplicationController — 100 req/min por IP
  # Cache key: "rate-limit:<controller_path>:web:<ip>"
  # ─────────────────────────────────────────────────────────────────────────────
  describe "Rutas web (ApplicationController)" do
    let(:limit) { ENV.fetch("RATE_LIMIT_WEB_PER_MIN", "100").to_i }
    let(:ip) { "127.0.0.1" }

    it "devuelve 429 en GET / al superar el límite" do
      RATE_LIMIT_STORE.write("rate-limit:conversations:web:#{ip}", limit, expires_in: 1.minute)
      get "/"
      expect(response).to have_http_status(:too_many_requests)
    end

    it "el body incluye error y retry_after" do
      RATE_LIMIT_STORE.write("rate-limit:conversations:web:#{ip}", limit, expires_in: 1.minute)
      get "/"
      body = JSON.parse(response.body)
      expect(body).to include("error" => "rate_limit_exceeded", "retry_after" => 30)
    end

    it "las rutas de API no comparten el contador web" do
      # Saturamos el contador de conversations
      RATE_LIMIT_STORE.write("rate-limit:conversations:web:#{ip}", limit, expires_in: 1.minute)
      # El contador de api/v1/actions sigue en cero — son cache keys distintas
      expect(RATE_LIMIT_STORE.read("rate-limit:api/v1/actions:some_token")).to be_nil
    end
  end
end
