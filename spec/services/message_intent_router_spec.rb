require "rails_helper"

RSpec.describe MessageIntentRouter do
  describe ".intercept" do
    context "preguntas de hora" do
      [
        "qué hora es",
        "Qué hora es",
        "qué hora es?",
        "Qué hora es Mikhael?",
        "qué hora son",
        "qué hora tenemos?",
        "qué hora tenés",
        "sabés qué hora es",
        "Sabes qué hora es Mikhael?",
        "me decís la hora?",
        "me decis la hora",
        "podés decirme la hora",
        "podes decirme la hora?",
        "tenés hora?",
        "tenes la hora",
        "what time is it",
        "what's the time"
      ].each do |question|
        it "intercepta '#{question}'" do
          result = described_class.intercept(question)
          expect(result).not_to be_nil
          expect(result.reply).to match(/Son las\s*\*?\d{2}:\d{2}/)
        end
      end
    end

    context "mensajes que NO son preguntas de hora actual" do
      [
        "hola",
        "qué hora cierra la farmacia",
        "sabés cuándo abre el banco",
        "me decís el código postal",
        "recordame en 2 horas tomar la pastilla"
      ].each do |msg|
        it "NO intercepta '#{msg}'" do
          expect(described_class.intercept(msg)).to be_nil
        end
      end
    end

    context "respuesta cuando no hay TZ configurada" do
      before do
        Setting.where(key: "user_timezone").delete_all
        ENV.delete("MIKHAEL_TZ")
      end

      it "muestra UTC con hint para configurar la zona" do
        result = described_class.intercept("qué hora es")
        expect(result.reply).to include("UTC")
        expect(result.reply).to match(/\/zona Buenos Aires/)
      end
    end

    context "respuesta con TZ configurada" do
      let(:user) { create(:user) }
      before do
        Current.user = user
        Setting.set_for(user, "user_timezone", "America/Argentina/Buenos_Aires")
      end

      it "muestra la hora en la zona del usuario con nombre amigable (sin _)" do
        result = described_class.intercept("qué hora es")
        expect(result.reply).to include("Buenos Aires")
        expect(result.reply).not_to match(/\/zona/)
      end

      it "NUNCA incluye '_' en la respuesta — rompe el Markdown de Telegram" do
        result = described_class.intercept("qué hora es")
        # Excluyendo los _ intencionales de las itálicas (que vienen pareados),
        # el nombre de zona no debe meter _ no balanceados.
        zone_section = result.reply[/\(([^)]+)\)/, 1]
        expect(zone_section).not_to include("_")
      end

      it "usa UserTimezone aunque Time.zone del thread esté en UTC" do
        Time.use_zone("UTC") do  # simula thread del poll job
          result = described_class.intercept("qué hora es")
          expect(result.reply).to include("Buenos Aires")
        end
      end
    end

    it "Result tiene reply (lo que ve el usuario) y assistant_persist (lo que se guarda en DB)" do
      user = create(:user)
      Current.user = user
      Setting.set_for(user, "user_timezone", "America/Argentina/Buenos_Aires")
      result = described_class.intercept("qué hora es")
      expect(result.reply).to include("🕐")        # con emoji y markdown
      expect(result.assistant_persist).not_to include("🕐")  # versión limpia para el historial
    end
  end
end
