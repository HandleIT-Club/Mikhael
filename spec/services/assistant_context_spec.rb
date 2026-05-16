require "rails_helper"

RSpec.describe AssistantContext do
  include ActiveSupport::Testing::TimeHelpers

  describe ".for" do
    it "rechaza superficies desconocidas" do
      expect { described_class.for(:smoke_signal) }.to raise_error(ArgumentError)
    end

    it "construye para :web y :telegram" do
      expect(described_class.for(:web)).to be_a(described_class)
      expect(described_class.for(:telegram)).to be_a(described_class)
    end
  end

  describe "#build" do
    it "incluye reglas críticas: no inventar estado, no inventar ejecución de acciones" do
      prompt = described_class.for(:web).build
      expect(prompt).to include("NUNCA inventes el estado")
      expect(prompt).to include("NUNCA simules ejecutar acciones")
      expect(prompt).to include("NUNCA simules programar recordatorios")
    end

    it "incluye los dos tools disponibles (call_device y create_reminder)" do
      prompt = described_class.for(:web).build
      expect(prompt).to include('"tool":"call_device"').and include('"tool":"create_reminder"')
    end

    it "incluye los dispositivos del usuario por device_id" do
      create(:device, device_id: "esp32_riego", name: "Riego")
      prompt = described_class.for(:web).build
      expect(prompt).to include("esp32_riego").and include("Riego")
    end

    it "incluye la hora actual (dynamic_prompt) cada turno" do
      prompt = described_class.for(:web).build
      expect(prompt).to match(/<hora_local>\d{4}-\d{2}-\d{2}/)
      expect(prompt).to match(/<hora_utc>\d{4}-\d{2}-\d{2}/)
    end

    it "diferencia el tono entre web y telegram (concision_rule)" do
      web_prompt = described_class.for(:web).build
      tg_prompt  = described_class.for(:telegram).build
      expect(web_prompt).not_to eq(tg_prompt)
      expect(tg_prompt).to include("chat móvil")
      expect(web_prompt).to include("chat real")
    end
  end

  describe "#fingerprint" do
    it "es el mismo entre llamadas dentro del mismo turno" do
      ctx = described_class.for(:web)
      expect(ctx.fingerprint).to eq(ctx.fingerprint)
    end

    it "NO depende de la hora (dynamic_prompt no entra al fingerprint)" do
      # Si dependiera, el fingerprint cambiaría cada vez que pasa un segundo
      # y la conversación cacheada se resetearía en cada mensaje.
      ctx     = described_class.for(:telegram)
      first   = ctx.fingerprint
      travel_to(1.hour.from_now) do
        expect(ctx.fingerprint).to eq(first)
      end
    end

    it "cambia cuando se agrega/borra un device" do
      ctx    = described_class.for(:telegram)
      before = ctx.fingerprint
      create(:device)
      expect(ctx.fingerprint).not_to eq(before)
    end
  end
end
