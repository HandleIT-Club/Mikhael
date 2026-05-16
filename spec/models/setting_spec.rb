require "rails_helper"

RSpec.describe Setting do
  describe ".get / .set" do
    it "persiste y recupera un valor por key" do
      described_class.set("foo", "bar")
      expect(described_class.get("foo")).to eq("bar")
    end

    it "devuelve el default cuando la key no existe" do
      expect(described_class.get("missing", "fallback")).to eq("fallback")
    end

    it "sobrescribe el valor cuando se vuelve a setear" do
      described_class.set("offset", "1")
      described_class.set("offset", "2")
      expect(described_class.get("offset")).to eq("2")
    end

    it "es idempotente (no lanza por unique constraint)" do
      expect { 3.times { described_class.set("k", "v") } }.not_to raise_error
      expect(described_class.where(key: "k", user_id: nil).count).to eq(1)
    end
  end

  describe ".get_for / .set_for (per-user)" do
    let(:alice) { create(:user) }
    let(:bob)   { create(:user) }

    it "cada user tiene su propio espacio de keys" do
      described_class.set_for(alice, "tz", "Buenos Aires")
      described_class.set_for(bob,   "tz", "Madrid")

      expect(described_class.get_for(alice, "tz")).to eq("Buenos Aires")
      expect(described_class.get_for(bob,   "tz")).to eq("Madrid")
    end

    it "el global (Setting.set) y el per-user no se pisan: comparten la key pero no el registro" do
      described_class.set("tz", "GMT")           # global, user_id: nil
      described_class.set_for(alice, "tz", "BA") # per-user, user_id: alice.id

      expect(described_class.get("tz")).to eq("GMT")
      expect(described_class.get_for(alice, "tz")).to eq("BA")
    end

    it "get_for con user=nil retorna el default" do
      expect(described_class.get_for(nil, "tz", "fallback")).to eq("fallback")
    end
  end
end
