require "rails_helper"

RSpec.describe CommandRouter do
  describe ".handle" do
    it "devuelve nil para texto que no es un comando slash" do
      expect(described_class.handle("hola mikhael")).to be_nil
    end

    describe "/start" do
      it "devuelve un saludo con la lista de comandos" do
        result = described_class.handle("/start")
        expect(result.reply).to include("Soy *Mikhael*").and include("/dispositivos").and include("/zona")
      end
    end

    describe "/dispositivos" do
      it "lista dispositivos cuando hay" do
        create(:device, device_id: "esp32_riego", name: "Riego")
        result = described_class.handle("/dispositivos")
        expect(result.reply).to include("Riego").and include("esp32_riego")
      end

      it "informa cuando no hay" do
        result = described_class.handle("/dispositivos")
        expect(result.reply).to match(/No hay dispositivos/i)
      end
    end

    describe "/recordatorios" do
      it "lista los pendientes" do
        create(:reminder, message: "alfa", scheduled_for: 1.hour.from_now)
        create(:reminder, message: "beta", scheduled_for: 2.hours.from_now)
        result = described_class.handle("/recordatorios")
        expect(result.reply).to match(/alfa/).and match(/beta/)
      end

      it "informa cuando no hay pendientes" do
        result = described_class.handle("/recordatorios")
        expect(result.reply).to match(/No hay recordatorios/i)
      end
    end

    describe "/borrar_recordatorio <id>" do
      it "borra uno existente" do
        reminder = create(:reminder)
        expect { described_class.handle("/borrar_recordatorio #{reminder.id}") }.to change(Reminder, :count).by(-1)
      end

      it "responde si no existe" do
        result = described_class.handle("/borrar_recordatorio 999")
        expect(result.reply).to match(/No existe/i)
      end

      it "rechaza borrar uno ejecutado" do
        reminder = create(:reminder, :executed)
        expect { described_class.handle("/borrar_recordatorio #{reminder.id}") }.not_to change(Reminder, :count)
      end
    end

    describe "/zona" do
      it "muestra la zona actual y la fuente" do
        Setting.set("user_timezone", "Madrid")
        result = described_class.handle("/zona")
        expect(result.reply).to match(/Zona actual:\s*\*Madrid\*/)
      end

      it "/zona Buenos Aires setea la zona" do
        described_class.handle("/zona Buenos Aires")
        expect(Setting.get("user_timezone")).to eq("Buenos Aires")
      end

      it "rechaza zonas inválidas" do
        result = described_class.handle("/zona Inválida/Tz")
        expect(result.reply).to match(/Zona desconocida/i)
        expect(Setting.get("user_timezone")).to be_nil
      end
    end

    describe "/reset" do
      it "devuelve un resultado y reset_command? true" do
        router = described_class.new("/reset")
        expect(router.reset_command?).to be(true)
        expect(router.handle.reply).to match(/Conversación reiniciada/)
      end
    end
  end
end
