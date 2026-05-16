require "rails_helper"

RSpec.describe ToolCallExecutor do
  let(:test_user) { create(:user) }

  before do
    allow(MqttPublisher).to receive(:publish)
    allow(TelegramClient).to receive(:send_message)
    allow(OllamaModels).to receive(:installed).and_return([])
  end

  describe "#call con call_device" do
    let(:device) { create(:device, device_id: "esp32_riego", name: "Riego") }
    let(:mock_client) { instance_double(Ai::RubyLlmClient) }
    let(:ai_response) do
      AiResponse.new(
        content:  '{"action":"open_valve","value":30,"reason":"humedad baja"}',
        model:    "llama-3.3-70b-versatile",
        provider: "groq"
      )
    end

    before do
      device
      allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
      allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
    end

    it "ejecuta DispatchAction y devuelve una confirmación" do
      executor = described_class.new(user_message: "abrí el riego", user: test_user)
      tool_json = %({"tool":"call_device","device_id":"esp32_riego","context":"abrir riego"})
      result    = executor.call(tool_json)
      expect(result.reply).to include("Riego").and include("open_valve")
    end

    it "publica al MQTT" do
      executor = described_class.new(user_message: "abrí el riego", user: test_user)
      tool_json = %({"tool":"call_device","device_id":"esp32_riego","context":"abrir"})
      executor.call(tool_json)
      expect(MqttPublisher).to have_received(:publish).with(device, hash_including(action: "open_valve"))
    end

    it "responde con error si el device no existe" do
      executor = described_class.new(user_message: "abrí algo", user: test_user)
      tool_json = %({"tool":"call_device","device_id":"no_existe","context":"x"})
      expect(executor.call(tool_json).reply).to match(/no encontrado/i)
    end
  end

  describe "#call con create_reminder" do
    it "crea el Reminder y encola el job" do
      executor = described_class.new(user_message: "recordame algo en 5 min", user: test_user)
      tool_json = %({"tool":"create_reminder","scheduled_for":"#{5.minutes.from_now.utc.iso8601}","message":"algo","kind":"notify","device_id":null})
      expect { executor.call(tool_json) }.to change(Reminder, :count).by(1).and have_enqueued_job(ExecuteReminderJob)
    end

    it "rechaza ISO8601 inválido pero recupera del user_message" do
      executor = described_class.new(user_message: "recordame en 5 minutos", user: test_user)
      tool_json = %({"tool":"create_reminder","scheduled_for":"YYYY-MM-DDTHH:MM:SSZ","message":"x","kind":"notify","device_id":null})
      expect { executor.call(tool_json) }.to change(Reminder, :count).by(1)
      expect(Reminder.last.scheduled_for).to be_within(1.minute).of(5.minutes.from_now)
    end

    it "rechaza hora del pasado pero recupera del user_message" do
      executor = described_class.new(user_message: "recordame en 5 minutos x", user: test_user)
      tool_json = %({"tool":"create_reminder","scheduled_for":"2020-01-01T00:00:00Z","message":"x","kind":"notify","device_id":null})
      expect { executor.call(tool_json) }.to change(Reminder, :count).by(1)
    end

    it "rechaza si kind=query_device y el device no existe" do
      executor = described_class.new(user_message: "recordame en 5 min", user: test_user)
      tool_json = %({"tool":"create_reminder","scheduled_for":"#{5.minutes.from_now.utc.iso8601}","message":"x","kind":"query_device","device_id":"no_existe"})
      expect { executor.call(tool_json) }.not_to change(Reminder, :count)
      expect(executor.call(tool_json).reply).to match(/No encontré el dispositivo/i)
    end

    it "dedup silencioso: segundo idéntico devuelve nil reply" do
      executor = described_class.new(user_message: "recordame en 5 min algo", user: test_user)
      tool_json = %({"tool":"create_reminder","scheduled_for":"#{5.minutes.from_now.utc.iso8601}","message":"algo","kind":"notify","device_id":null})
      executor.call(tool_json)
      result = executor.call(tool_json)
      expect(result).to be_nil
    end
  end

  describe "#call fallback cuando el AI NO usa el tool" do
    it "detecta intención de recordatorio y crea uno desde el user_message" do
      executor = described_class.new(user_message: "recordame en 10 minutos cerrar la puerta", user: test_user)
      result = executor.call("¡Claro! Te aviso en 10 minutos.")  # AI ignoró el tool
      expect(result).not_to be_nil
      expect(Reminder.last.message).to eq("cerrar la puerta")
    end

    it "soporta verbo en infinitivo: 'podrías recordarme...'" do
      executor = described_class.new(user_message: "Podrías recordarme en 1 hora hacer las empanadas?", user: test_user)
      result = executor.call("¡Claro!")
      expect(result).not_to be_nil
      expect(Reminder.last.scheduled_for).to be_within(1.minute).of(1.hour.from_now)
    end

    it "soporta vos imperativo: 'recordame'" do
      executor = described_class.new(user_message: "recordame en 30 minutos llamar", user: test_user)
      result = executor.call("¡Listo!")
      expect(result).not_to be_nil
    end

    it "soporta 'avisame en X'" do
      executor = described_class.new(user_message: "avisame en 2 horas", user: test_user)
      result = executor.call("Ok")
      expect(result).not_to be_nil
    end

    it "devuelve nil si no es tool call ni intención de recordatorio" do
      executor = described_class.new(user_message: "hola, cómo estás?", user: test_user)
      expect(executor.call("¡Hola! Todo bien.")).to be_nil
    end
  end
end
