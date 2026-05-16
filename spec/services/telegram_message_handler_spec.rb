require "rails_helper"

# Después del refactor multi-user, TelegramMessageHandler es un shim delgado
# que solo orquesta CommandRouter / MessageIntentRouter / ToolCallExecutor.
# La lógica de cada uno se testea en su propio spec; acá solo testeamos
# que el shim los conecta bien y que respeta el user/chat_id correcto.

RSpec.describe TelegramMessageHandler do
  let(:user)        { create(:user, :with_telegram) }
  let(:handler)     { described_class.new(user: user, chat_id: user.telegram_chat_id) }
  let(:mock_client) { instance_double(Ai::RubyLlmClient) }
  let(:ai_content)  { "respuesta default del AI" }
  let(:ai_response) { AiResponse.new(content: ai_content, model: "m", provider: "p") }

  before do
    allow(TelegramClient).to receive(:send_message)
    allow(MqttPublisher).to receive(:publish)
    allow(OllamaModels).to receive(:installed).and_return([])
    stub_ai_provider!
    allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
    allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
    allow(mock_client).to receive(:stream).and_return(Dry::Monads::Success(ai_response))
  end

  describe "ignora si no hay user" do
    it "no manda nada si user es nil" do
      described_class.new(user: nil, chat_id: "x").call("hola")
      expect(TelegramClient).not_to have_received(:send_message)
    end
  end

  describe "siempre manda al chat_id correcto" do
    let(:ai_content) { "respuesta" }

    it "send_message recibe el chat_id del user del handler" do
      handler.call("hola")
      expect(TelegramClient).to have_received(:send_message)
        .with(anything, chat_id: user.telegram_chat_id)
    end
  end

  describe "comandos slash (delegados a CommandRouter)" do
    it "/dispositivos responde con la lista" do
      create(:device, device_id: "esp32_riego", name: "Riego")
      handler.call("/dispositivos")
      expect(TelegramClient).to have_received(:send_message).with(/Riego/, chat_id: user.telegram_chat_id)
    end

    it "/recordatorios lista los del USER (no de otros)" do
      mine     = create(:reminder, user: user,                 message: "mio")
      other_u  = create(:user)
      _other_r = create(:reminder, user: other_u,              message: "ajeno")

      handler.call("/recordatorios")
      expect(TelegramClient).to have_received(:send_message)
        .with(satisfy { |s| s.include?("mio") && !s.include?("ajeno") }, chat_id: user.telegram_chat_id)
    end

    it "/zona persiste para EL USER (no global)" do
      handler.call("/zona Buenos Aires")
      expect(Setting.get_for(user, "user_timezone")).to eq("Buenos Aires")
    end
  end

  describe "intent router (delegado a MessageIntentRouter)" do
    it "'qué hora es' responde sin tocar al AI" do
      handler.call("qué hora es")
      expect(mock_client).not_to have_received(:chat)
    end
  end

  describe "tool calls (delegados a ToolCallExecutor)" do
    let(:future_iso) { 5.minutes.from_now.utc.iso8601 }

    context "create_reminder" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"#{future_iso}","message":"dormir","kind":"notify","device_id":null})
      end

      it "crea el Reminder OWNED por el user del handler" do
        expect { handler.call("recordame en 5 min dormir") }.to change(user.reminders, :count).by(1)
      end

      it "encola ExecuteReminderJob" do
        expect { handler.call("recordame en 5 min dormir") }.to have_enqueued_job(ExecuteReminderJob)
      end
    end

    context "fallback (AI responde chat text)" do
      let(:ai_content) { "¡Claro!" }

      it "crea Reminder owned por el user vía REMINDER_INTENT_RE" do
        expect { handler.call("podrías recordarme en 1 hora algo importante") }
          .to change(user.reminders, :count).by(1)
      end
    end
  end

  describe "chat normal sin tool ni intent ni comando" do
    let(:ai_content) { "¡Hola!" }

    it "responde con el contenido del AI tal cual" do
      handler.call("hola")
      expect(TelegramClient).to have_received(:send_message).with("¡Hola!", chat_id: user.telegram_chat_id)
    end
  end

  describe "/reset" do
    it "borra la conversación cacheada del user" do
      handler.call("hola")  # crea conversación cacheada
      expect(user.conversations.count).to eq(1)
      handler.call("/reset")
      expect(user.conversations.count).to eq(0)
    end
  end
end
