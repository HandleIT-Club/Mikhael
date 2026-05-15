require "rails_helper"

RSpec.describe TelegramMessageHandler do
  subject(:handler) { described_class.new }

  let(:mock_client) { instance_double(Ai::RubyLlmClient) }
  let(:ai_response) { AiResponse.new(content: ai_content, model: "m", provider: "p") }
  let(:ai_content)  { "respuesta default" }

  before do
    allow(TelegramClient).to receive(:send_message)
    allow(MqttPublisher).to receive(:publish)
    allow(OllamaModels).to receive(:installed).and_return([])
    allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
    allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
    allow(mock_client).to receive(:stream).and_return(Dry::Monads::Success(ai_response))
  end

  describe "tool create_reminder" do
    let(:future_iso) { 5.minutes.from_now.utc.iso8601 }

    context "kind=notify" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"#{future_iso}","message":"irse a dormir","kind":"notify","device_id":null})
      end

      it "crea el Reminder en la DB" do
        expect { handler.call("recordame en 5 minutos de dormir") }.to change(Reminder, :count).by(1)
      end

      it "encola ExecuteReminderJob con wait_until" do
        expect {
          handler.call("recordame en 5 minutos de dormir")
        }.to have_enqueued_job(ExecuteReminderJob)
      end

      it "responde con confirmación numerada" do
        handler.call("recordame en 5 minutos de dormir")
        expect(TelegramClient).to have_received(:send_message).with(/Recordatorio #\d+ programado/)
      end
    end

    context "kind=query_device con id_string" do
      let(:device) { create(:device, device_id: "esp32_riego") }
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"#{future_iso}","message":"cómo está el riego","kind":"query_device","device_id":"esp32_riego"})
      end

      before { device }

      it "resuelve el id_string al FK numérico" do
        handler.call("mañana a las 8 preguntale al riego cómo está")
        expect(Reminder.last.device_id).to eq(device.id)
      end
    end

    context "scheduled_for completamente inválido" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"cualquier cosa","message":"x","kind":"notify","device_id":null})
      end

      it "no crea el Reminder y avisa al usuario incluyendo el valor crudo" do
        expect { handler.call("recordame algo") }.not_to change(Reminder, :count)
        expect(TelegramClient).to have_received(:send_message).with(/no entendí la hora.*cualquier cosa/m)
      end
    end

    context "scheduled_for en lenguaje natural ('en 5 minutos')" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"en 5 minutos","message":"dormir","kind":"notify","device_id":null})
      end

      it "lo parsea como fallback y crea el Reminder" do
        expect { handler.call("recordame en 5 minutos dormir") }.to change(Reminder, :count).by(1)
        expect(Reminder.last.scheduled_for).to be_within(1.minute).of(5.minutes.from_now)
      end
    end

    context "scheduled_for sin prefijo ('5 minutos desde ahora')" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"5 minutos desde ahora","message":"dormir","kind":"notify","device_id":null})
      end

      it "captura el número+unidad sin importar palabras alrededor" do
        expect { handler.call("recordame algo") }.to change(Reminder, :count).by(1)
        expect(Reminder.last.scheduled_for).to be_within(1.minute).of(5.minutes.from_now)
      end
    end

    context "scheduled_for en inglés ('in 2 hours')" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"in 2 hours","message":"x","kind":"notify","device_id":null})
      end

      it "también lo parsea" do
        expect { handler.call("remind me in 2 hours") }.to change(Reminder, :count).by(1)
        expect(Reminder.last.scheduled_for).to be_within(1.minute).of(2.hours.from_now)
      end
    end

    context "scheduled_for vacío pero el message tiene la hora" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"","message":"en 10 minutos cerrar la puerta","kind":"notify","device_id":null})
      end

      it "lo extrae del message como fallback" do
        expect { handler.call("recordame cerrar la puerta") }.to change(Reminder, :count).by(1)
        expect(Reminder.last.scheduled_for).to be_within(1.minute).of(10.minutes.from_now)
      end
    end

    context "AI devuelve el placeholder literal 'YYYY-MM-DD...'" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"YYYY-MM-DDTHH:MM:SSZ","message":"x","kind":"notify","device_id":null})
      end

      it "rechaza el placeholder y avisa" do
        expect { handler.call("recordame algo") }.not_to change(Reminder, :count)
        expect(TelegramClient).to have_received(:send_message).with(/no entendí la hora/)
      end
    end

    context "AI devuelve un placeholder con número embebido ('<UTC ahora+5min>')" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"<UTC ahora+5min>","message":"x","kind":"notify","device_id":null})
      end

      it "extrae el 5min del placeholder y honra la intención del usuario" do
        expect { handler.call("recordame algo en 5 minutos") }.to change(Reminder, :count).by(1)
        expect(Reminder.last.scheduled_for).to be_within(1.minute).of(5.minutes.from_now)
      end
    end

    context "scheduled_for en el pasado SIN señal en el mensaje del usuario" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"#{1.hour.ago.utc.iso8601}","message":"x","kind":"notify","device_id":null})
      end

      it "rechaza el recordatorio" do
        expect { handler.call("recordame algo") }.not_to change(Reminder, :count)
        expect(TelegramClient).to have_received(:send_message).with(/ya pasó/)
      end
    end

    # Caso real visto en producción: usuario dice "mañana a las 15" estando en
    # mayo, el AI devuelve enero (alucinado), pero el mensaje del usuario tiene
    # la intención clara. Cubierto el caso simple "en X minutos".
    context "AI alucina una fecha en el pasado PERO el user dijo 'en X minutos'" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"2026-01-15T10:00:00Z","message":"ir a dormir","kind":"notify","device_id":null})
      end

      it "recupera la intención del mensaje del usuario" do
        expect {
          handler.call("recordame ir a dormir en 2 minutos")
        }.to change(Reminder, :count).by(1)
        expect(Reminder.last.scheduled_for).to be_within(1.minute).of(2.minutes.from_now)
      end
    end

    context "device_id desconocido en kind=query_device" do
      let(:ai_content) do
        %({"tool":"create_reminder","scheduled_for":"#{future_iso}","message":"x","kind":"query_device","device_id":"no_existe"})
      end

      it "no crea el Reminder y avisa" do
        expect { handler.call("recordame algo") }.not_to change(Reminder, :count)
        expect(TelegramClient).to have_received(:send_message).with(/no encontré el dispositivo/i)
      end
    end
  end

  describe "comando /recordatorios" do
    it "lista los recordatorios pendientes" do
      create(:reminder, message: "uno", scheduled_for: 1.hour.from_now)
      create(:reminder, message: "dos", scheduled_for: 2.hours.from_now)
      handler.call("/recordatorios")
      expect(TelegramClient).to have_received(:send_message).with(/uno.*dos/m)
    end

    it "informa cuando no hay pendientes" do
      handler.call("/recordatorios")
      expect(TelegramClient).to have_received(:send_message).with(/No hay recordatorios pendientes/)
    end
  end

  describe "comando /borrar_recordatorio" do
    it "borra un recordatorio existente" do
      reminder = create(:reminder)
      expect { handler.call("/borrar_recordatorio #{reminder.id}") }.to change(Reminder, :count).by(-1)
    end

    it "responde si el id no existe" do
      handler.call("/borrar_recordatorio 999999")
      expect(TelegramClient).to have_received(:send_message).with(/No existe/)
    end

    it "no permite borrar uno ya ejecutado" do
      reminder = create(:reminder, :executed)
      expect { handler.call("/borrar_recordatorio #{reminder.id}") }.not_to change(Reminder, :count)
      expect(TelegramClient).to have_received(:send_message).with(/ya fue ejecutado/)
    end
  end
end
