require "rails_helper"

RSpec.describe ExecuteReminderJob do
  let(:user) { create(:user, :with_telegram) }

  before do
    allow(TelegramClient).to receive(:send_message)
    allow(MqttPublisher).to receive(:publish)
    allow(OllamaModels).to receive(:installed).and_return([])
  end

  describe "#perform" do
    context "cuando el reminder no existe" do
      it "no lanza error" do
        expect { described_class.perform_now(999_999) }.not_to raise_error
      end

      it "no manda mensaje a Telegram" do
        described_class.perform_now(999_999)
        expect(TelegramClient).not_to have_received(:send_message)
      end
    end

    context "cuando el reminder ya fue ejecutado (idempotencia)" do
      let(:reminder) { create(:reminder, :executed, user: user) }

      it "no manda mensaje a Telegram" do
        described_class.perform_now(reminder.id)
        expect(TelegramClient).not_to have_received(:send_message)
      end

      it "no actualiza executed_at" do
        original = reminder.executed_at
        described_class.perform_now(reminder.id)
        expect(reminder.reload.executed_at).to be_within(1.second).of(original)
      end
    end

    context "cuando el user del reminder no tiene telegram_chat_id" do
      let(:user_no_tg) { create(:user) } # sin :with_telegram
      let(:reminder)   { create(:reminder, :past, user: user_no_tg) }

      it "no manda mensaje pero marca executed_at" do
        described_class.perform_now(reminder.id)
        expect(TelegramClient).not_to have_received(:send_message)
        expect(reminder.reload.executed_at).to be_present
      end
    end

    context "kind=notify" do
      let(:reminder) { create(:reminder, :past, user: user, message: "Revisar el riego") }

      it "manda el mensaje al chat_id del user" do
        described_class.perform_now(reminder.id)
        expect(TelegramClient).to have_received(:send_message)
          .with(/Revisar el riego/, chat_id: user.telegram_chat_id)
      end

      it "marca executed_at" do
        described_class.perform_now(reminder.id)
        expect(reminder.reload.executed_at).to be_present
      end
    end

    context "kind=query_device con device válido" do
      let(:device)   { create(:device) }
      let(:reminder) { create(:reminder, :past, user: user, kind: "query_device", device_id: device.id, message: "humedad?") }
      let(:mock_client) { instance_double(Ai::RubyLlmClient) }
      let(:ai_response) do
        AiResponse.new(content: '{"action":"read","value":null,"reason":"45%"}', model: "m", provider: "groq")
      end

      before do
        allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
        allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
      end

      it "llama DispatchAction y manda resultado al chat del user" do
        described_class.perform_now(reminder.id)
        expect(TelegramClient).to have_received(:send_message)
          .with(/read/, chat_id: user.telegram_chat_id)
      end
    end

    context "kind=query_device con device_id inexistente" do
      let(:reminder) { create(:reminder, :past, user: user, kind: "query_device", device_id: 999_999, message: "x") }

      it "no lanza error y manda mensaje de error" do
        expect { described_class.perform_now(reminder.id) }.not_to raise_error
        expect(TelegramClient).to have_received(:send_message)
          .with(/no se encontró el dispositivo/i, chat_id: user.telegram_chat_id)
      end
    end
  end
end
