require "rails_helper"

RSpec.describe ExecuteReminderJob do
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
      let(:reminder) { create(:reminder, :executed) }

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

    context "kind=notify" do
      let(:reminder) { create(:reminder, :past, message: "Revisar el riego") }

      it "manda el mensaje a Telegram" do
        described_class.perform_now(reminder.id)
        expect(TelegramClient).to have_received(:send_message).with(/Revisar el riego/)
      end

      it "marca executed_at" do
        described_class.perform_now(reminder.id)
        expect(reminder.reload.executed_at).to be_present
      end
    end

    context "kind=query_device con device válido" do
      let(:device)   { create(:device) }
      let(:reminder) do
        create(:reminder, :past, kind: "query_device", device_id: device.id,
               message: "cómo está la humedad")
      end

      let(:mock_client) { instance_double(Ai::RubyLlmClient) }
      let(:ai_response) do
        AiResponse.new(
          content:  '{"action":"read_sensor","value":null,"reason":"humedad al 45%"}',
          model:    "llama-3.3-70b-versatile",
          provider: "groq"
        )
      end

      before do
        allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
        allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
      end

      it "llama DispatchAction y manda resultado a Telegram" do
        described_class.perform_now(reminder.id)
        expect(TelegramClient).to have_received(:send_message).with(/read_sensor/)
      end

      it "marca executed_at" do
        described_class.perform_now(reminder.id)
        expect(reminder.reload.executed_at).to be_present
      end
    end

    context "kind=query_device con device_id inexistente" do
      let(:reminder) do
        create(:reminder, :past, kind: "query_device", device_id: 999_999,
               message: "consultar sensor")
      end

      it "no lanza error" do
        expect { described_class.perform_now(reminder.id) }.not_to raise_error
      end

      it "manda mensaje de error a Telegram" do
        described_class.perform_now(reminder.id)
        expect(TelegramClient).to have_received(:send_message).with(/no se encontró el dispositivo/i)
      end

      it "marca executed_at igualmente" do
        described_class.perform_now(reminder.id)
        expect(reminder.reload.executed_at).to be_present
      end
    end

    context "cuando TelegramClient lanza una excepción" do
      let(:reminder) { create(:reminder, :past) }

      before do
        allow(TelegramClient).to receive(:send_message).and_raise(StandardError, "network error")
      end

      it "no propaga el error" do
        expect { described_class.perform_now(reminder.id) }.not_to raise_error
      end

      it "marca executed_at igualmente" do
        described_class.perform_now(reminder.id)
        expect(reminder.reload.executed_at).to be_present
      end
    end
  end
end
