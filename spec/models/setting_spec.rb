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
      expect(described_class.where(key: "k").count).to eq(1)
    end
  end
end
