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
    before { Current.user = user }

    it "persiste la zona para el Current.user y actualiza Time.zone" do
      described_class.set("America/Argentina/Buenos_Aires")
      expect(Setting.get_for(user, "user_timezone")).to eq("America/Argentina/Buenos_Aires")
      expect(Time.zone.name).to eq("America/Argentina/Buenos_Aires")
    end

    it "retorna true si la zona es válida" do
      expect(described_class.set("Madrid")).to be(true)
    end

    it "retorna false si la zona es inválida" do
      expect(described_class.set("Inválida/Tz")).to be(false)
      expect(Setting.get_for(user, "user_timezone")).to be_nil
    end

    it "retorna false si no hay Current.user (no podemos persistir sin dueño)" do
      Current.user = nil
      expect(described_class.set("Madrid")).to be(false)
    end
  end
end
