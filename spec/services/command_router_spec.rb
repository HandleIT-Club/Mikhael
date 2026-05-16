require "rails_helper"

RSpec.describe CommandRouter do
  let(:test_user) { create(:user) }

  describe ".handle" do
    it "devuelve nil para texto que no es un comando slash" do
      expect(described_class.handle("hola mikhael", user: test_user)).to be_nil
    end

    describe "/start" do
      it "devuelve un saludo con la lista de comandos" do
        result = described_class.handle("/start", user: test_user)
        expect(result.reply).to include("Soy *Mikhael*").and include("/dispositivos").and include("/zona")
      end
    end

    describe "/dispositivos" do
      it "lista dispositivos cuando hay" do
        create(:device, device_id: "esp32_riego", name: "Riego")
        result = described_class.handle("/dispositivos", user: test_user)
        expect(result.reply).to include("Riego").and include("esp32_riego")
      end

      it "informa cuando no hay" do
        result = described_class.handle("/dispositivos", user: test_user)
        expect(result.reply).to match(/No hay dispositivos/i)
      end
    end

    describe "/recordatorios" do
      it "lista los pendientes del USER" do
        create(:reminder, user: test_user, message: "alfa", scheduled_for: 1.hour.from_now)
        create(:reminder, user: test_user, message: "beta", scheduled_for: 2.hours.from_now)
        # De otro user — no deben aparecer
        create(:reminder, message: "ajeno", scheduled_for: 1.hour.from_now)

        result = described_class.handle("/recordatorios", user: test_user)
        expect(result.reply).to match(/alfa/).and match(/beta/)
        expect(result.reply).not_to match(/ajeno/)
      end

      it "informa cuando no hay pendientes" do
        result = described_class.handle("/recordatorios", user: test_user)
        expect(result.reply).to match(/No hay recordatorios/i)
      end
    end

    describe "/borrar_recordatorio <id>" do
      it "borra uno existente del USER" do
        reminder = create(:reminder, user: test_user)
        expect { described_class.handle("/borrar_recordatorio #{reminder.id}", user: test_user) }.to change(Reminder, :count).by(-1)
      end

      it "NO permite borrar uno de otro user (scoping)" do
        other_reminder = create(:reminder)
        expect { described_class.handle("/borrar_recordatorio #{other_reminder.id}", user: test_user) }.not_to change(Reminder, :count)
      end

      it "responde si no existe" do
        result = described_class.handle("/borrar_recordatorio 999", user: test_user)
        expect(result.reply).to match(/No existe/i)
      end

      it "rechaza borrar uno ejecutado" do
        reminder = create(:reminder, :executed)
        expect { described_class.handle("/borrar_recordatorio #{reminder.id}", user: test_user) }.not_to change(Reminder, :count)
      end
    end

    describe "/zona" do
      it "muestra la zona actual y la fuente" do
        Setting.set_for(test_user, "user_timezone", "Madrid")
        result = described_class.handle("/zona", user: test_user)
        expect(result.reply).to match(/Zona actual:\s*\*Madrid\*/)
      end

      it "/zona Buenos Aires setea la zona del user" do
        described_class.handle("/zona Buenos Aires", user: test_user)
        expect(Setting.get_for(test_user, "user_timezone")).to eq("Buenos Aires")
      end

      it "rechaza zonas inválidas" do
        result = described_class.handle("/zona Inválida/Tz", user: test_user)
        expect(result.reply).to match(/Zona desconocida/i)
        expect(Setting.get_for(test_user, "user_timezone")).to be_nil
      end
    end

    describe "/reset" do
      it "devuelve un resultado y reset_command? true" do
        router = described_class.new("/reset", user: test_user)
        expect(router.reset_command?).to be(true)
        expect(router.handle.reply).to match(/Conversación reiniciada/)
      end
    end
  end
end
