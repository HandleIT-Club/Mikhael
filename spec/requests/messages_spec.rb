require "rails_helper"

RSpec.describe "Web MessagesController", type: :request do
  let(:user)         { create(:user) }
  let(:conversation) { create(:conversation, user: user) }
  let(:mock_client)  { instance_double(Ai::RubyLlmClient) }
  let(:ai_content)   { "respuesta del AI" }
  let(:ai_response)  { AiResponse.new(content: ai_content, model: "m", provider: "p") }

  before do
    allow(OllamaModels).to receive(:installed).and_return([])
    stub_ai_provider!
    allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
    allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
    allow(mock_client).to receive(:stream).and_return(Dry::Monads::Success(ai_response))
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to)

    sign_in_as(user)
  end

  def post_message(text)
    post conversation_messages_path(conversation),
         params:  { message: { content: text } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  describe "slash commands" do
    it "/dispositivos no llama al AI y persiste un assistant message" do
      create(:device, device_id: "esp32_riego", name: "Riego")
      expect { post_message("/dispositivos") }.to change(conversation.messages, :count).by(2)  # user + assistant
      expect(mock_client).not_to have_received(:chat)
      expect(mock_client).not_to have_received(:stream)
      expect(conversation.messages.last.content).to include("Riego")
    end

    it "/zona setea la zona y persiste la confirmación" do
      post_message("/zona Buenos Aires")
      expect(Setting.get_for(user, "user_timezone")).to eq("Buenos Aires")
      expect(conversation.messages.last.content).to match(/configurada/i)
    end

    it "/recordatorios lista los pendientes del user" do
      create(:reminder, user: user, message: "test")
      post_message("/recordatorios")
      expect(conversation.messages.last.content).to include("test")
    end
  end

  describe "intent router" do
    it "'qué hora es' responde determinístico, sin tocar al AI" do
      post_message("qué hora es")
      expect(mock_client).not_to have_received(:chat)
      expect(mock_client).not_to have_received(:stream)
      expect(conversation.messages.last.content).to match(/Son las/)
    end

    it "'cómo están los dispositivos' responde con la lista real, no con alucinaciones del AI" do
      create(:device, device_id: "esp32_cerradura", name: "Cerradura")
      post_message("cómo están los dispositivos")
      expect(mock_client).not_to have_received(:chat)
      expect(mock_client).not_to have_received(:stream)
      # El persist es un resumen corto para la conversación; lo importante
      # es que vino de Rails (no del AI) y menciona el device real.
      expect(conversation.messages.last.content).to include("Cerradura")
    end
  end

  describe "tool call execution" do
    context "call_device" do
      let(:device)     { create(:device, device_id: "esp32_riego", name: "Riego") }
      let(:ai_content) { %({"tool":"call_device","device_id":"esp32_riego","context":"abrir riego"}) }
      let(:dispatch_response) do
        AiResponse.new(
          content:  '{"action":"open_valve","value":30,"reason":"el usuario lo pidió"}',
          model:    "llama-3.3-70b-versatile",
          provider: "groq"
        )
      end

      before do
        device
        allow(MqttPublisher).to receive(:publish)
        # En web el chat principal va por #stream (con on_chunk) y devuelve el
        # tool call. DispatchAction usa #chat (no streaming) y devuelve el JSON
        # estructurado de la acción.
        allow(mock_client).to receive(:stream).and_return(Dry::Monads::Success(ai_response))
        allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(dispatch_response))
      end

      it "ejecuta DispatchAction y publica al MQTT (no muestra JSON crudo)" do
        post_message("abrí el riego")
        expect(MqttPublisher).to have_received(:publish).with(device, hash_including(action: "open_valve"))
        # El assistant message persistido debe ser el resultado de la acción, no el JSON crudo
        last = conversation.messages.where(role: "assistant").last
        expect(last.content).to include("Riego").and include("open_valve")
        expect(last.content).not_to include('"tool":"call_device"')
      end
    end

    context "create_reminder" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"#{5.minutes.from_now.utc.iso8601}","message":"llamar al doctor","kind":"notify","device_id":null})
      end

      it "crea el Reminder y encola el job" do
        expect { post_message("recordame en 5 minutos llamar al doctor") }
          .to change(Reminder, :count).by(1).and have_enqueued_job(ExecuteReminderJob)
      end

      it "persiste un assistant message con la confirmación (no JSON crudo)" do
        post_message("recordame en 5 minutos llamar al doctor")
        last = conversation.messages.where(role: "assistant").last
        expect(last.content).to include("Recordatorio")
        expect(last.content).not_to include('"tool":"create_reminder"')
      end
    end

    context "AI omite el tool pero el user pidió un recordatorio" do
      let(:ai_content) { "¡Claro! Te aviso en 1 hora." }  # chat text, sin tool

      it "fallback determinístico: crea el Reminder igual" do
        expect { post_message("podrías recordarme en 1 hora hacer las empanadas?") }
          .to change(Reminder, :count).by(1)
      end
    end
  end

  describe "chat normal (sin tool ni intent ni comando)" do
    let(:ai_content) { "¡Hola! ¿En qué te ayudo?" }

    it "guarda el mensaje del AI tal cual" do
      post_message("hola mikhael")
      expect(conversation.messages.last.content).to eq(ai_content)
    end
  end

  describe "validación" do
    it "rechaza mensajes vacíos" do
      post_message("   ")
      expect(conversation.messages).to be_empty
    end
  end

  describe "POST transcribe (voz)" do
    let(:whisper)    { instance_double(Ai::WhisperClient) }
    let(:audio_file) { Rack::Test::UploadedFile.new(StringIO.new("fake-audio"), "audio/webm", true, original_filename: "voice.webm") }

    before do
      allow(Ai::WhisperClient).to receive(:new).and_return(whisper)
    end

    def post_audio(file = audio_file)
      post transcribe_conversation_messages_path(conversation),
           params: { audio: file }
    end

    it "devuelve el texto transcripto con 200" do
      allow(whisper).to receive(:transcribe).and_return(Dry::Monads::Success("apagá la luz"))
      post_audio
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["text"]).to eq("apagá la luz")
    end

    it "devuelve 429 cuando Whisper alcanza el límite diario" do
      allow(whisper).to receive(:transcribe).and_return(Dry::Monads::Failure(:rate_limited))
      post_audio
      expect(response).to have_http_status(:too_many_requests)
      expect(JSON.parse(response.body)["error"]).to eq("rate_limited")
    end

    it "devuelve 503 cuando Whisper no está configurado" do
      allow(whisper).to receive(:transcribe).and_return(Dry::Monads::Failure(:whisper_unavailable))
      post_audio
      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)["error"]).to eq("unavailable")
    end

    it "devuelve 422 cuando la transcripción falla" do
      allow(whisper).to receive(:transcribe).and_return(Dry::Monads::Failure(:ai_error))
      post_audio
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to eq("failed")
    end

    it "devuelve 400 si no se envía audio" do
      post transcribe_conversation_messages_path(conversation)
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)["error"]).to eq("no_audio")
    end
  end
end
