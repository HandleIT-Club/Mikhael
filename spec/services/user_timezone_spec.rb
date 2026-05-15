require "rails_helper"

RSpec.describe UserTimezone do
  describe ".current" do
    it "devuelve la zona guardada en Setting si existe" do
      Setting.set("user_timezone", "America/Argentina/Buenos_Aires")
      expect(described_class.current).to eq("America/Argentina/Buenos_Aires")
    end

    it "cae al ENV MIKHAEL_TZ si no hay Setting" do
      Setting.where(key: "user_timezone").delete_all
      ClimateControl.modify(MIKHAEL_TZ: "Madrid") do
        expect(described_class.current).to eq("Madrid")
      end
    rescue NameError
      # Si ClimateControl no está disponible, ENV directo
      ENV["MIKHAEL_TZ"] = "Madrid"
      Setting.where(key: "user_timezone").delete_all
      expect(described_class.current).to eq("Madrid")
    ensure
      ENV.delete("MIKHAEL_TZ")
    end

    it "cae a UTC si no hay nada seteado" do
      Setting.where(key: "user_timezone").delete_all
      ENV.delete("MIKHAEL_TZ")
      expect(described_class.current).to eq("UTC")
    end
  end

  describe ".set" do
    it "persiste la zona en Setting y actualiza Time.zone" do
      described_class.set("America/Argentina/Buenos_Aires")
      expect(Setting.get("user_timezone")).to eq("America/Argentina/Buenos_Aires")
      expect(Time.zone.name).to eq("America/Argentina/Buenos_Aires")
    end

    it "retorna true si la zona es válida" do
      expect(described_class.set("Madrid")).to be(true)
    end

    it "retorna false y no persiste si la zona es inválida" do
      Setting.where(key: "user_timezone").delete_all
      expect(described_class.set("Inválida/Tz")).to be(false)
      expect(Setting.get("user_timezone")).to be_nil
    end
  end
end
