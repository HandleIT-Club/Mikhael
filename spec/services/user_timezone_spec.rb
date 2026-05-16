require "rails_helper"

RSpec.describe UserTimezone do
  let(:user) { create(:user) }

  describe ".current" do
    it "devuelve la zona guardada para Current.user si hay sesión" do
      Setting.set_for(user, "user_timezone", "America/Argentina/Buenos_Aires")
      Current.user = user
      expect(described_class.current).to eq("America/Argentina/Buenos_Aires")
    end

    it "cae al ENV MIKHAEL_TZ si no hay Current.user" do
      Current.user = nil
      ENV["MIKHAEL_TZ"] = "Madrid"
      expect(described_class.current).to eq("Madrid")
    ensure
      ENV.delete("MIKHAEL_TZ")
    end

    it "cae al ENV si Current.user existe pero no tiene Setting" do
      Current.user = user
      ENV["MIKHAEL_TZ"] = "Madrid"
      expect(described_class.current).to eq("Madrid")
    ensure
      ENV.delete("MIKHAEL_TZ")
    end

    it "cae a UTC si no hay user ni ENV" do
      Current.user = nil
      ENV.delete("MIKHAEL_TZ")
      expect(described_class.current).to eq("UTC")
    end
  end

  describe ".set" do
    it "persiste la zona para el user dado y actualiza Time.zone" do
      described_class.set("America/Argentina/Buenos_Aires", user: user)
      expect(Setting.get_for(user, "user_timezone")).to eq("America/Argentina/Buenos_Aires")
      expect(Time.zone.name).to eq("America/Argentina/Buenos_Aires")
    end

    it "retorna true si la zona es válida" do
      expect(described_class.set("Madrid", user: user)).to be(true)
    end

    it "retorna false si la zona es inválida" do
      expect(described_class.set("Inválida/Tz", user: user)).to be(false)
      expect(Setting.get_for(user, "user_timezone")).to be_nil
    end

    it "retorna false si user es nil" do
      expect(described_class.set("Madrid", user: nil)).to be(false)
    end

    it "default: user lo toma de Current.user si no se pasa" do
      Current.user = user
      expect(described_class.set("Madrid")).to be(true)
      expect(Setting.get_for(user, "user_timezone")).to eq("Madrid")
    end
  end
end
