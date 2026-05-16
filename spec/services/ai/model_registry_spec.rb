require "rails_helper"

RSpec.describe Ai::ModelRegistry do
  before do
    described_class.reset!
    allow(OllamaModels).to receive(:installed).and_return([])
  end

  describe ".all_models" do
    it "incluye TODOS los cloud (sin importar ENV) — es el catálogo para validar" do
      ENV.delete("GROQ_API_KEY")
      result = described_class.all_models
      expect(result["llama-3.3-70b-versatile"]).to eq("groq")
      expect(result["cerebras/llama-3.3-70b"]).to eq("cerebras")
    end

    it "incluye Ollama instalado" do
      allow(OllamaModels).to receive(:installed).and_return([ "llama3.2:3b" ])
      expect(described_class.all_models["llama3.2:3b"]).to eq("ollama")
    end

    it "memoiza dentro del TTL" do
      first  = described_class.all_models
      second = described_class.all_models
      expect(first).to equal(second) # misma referencia
    end

    it "reset! rompe el memo" do
      first = described_class.all_models
      described_class.reset!
      expect(described_class.all_models).not_to equal(first)
    end
  end

  describe ".cloud_model_ids" do
    it "filtra por ENV: si GROQ_API_KEY está vacío, no aparecen modelos de Groq" do
      ENV.delete("GROQ_API_KEY")
      expect(described_class.cloud_model_ids).not_to include("llama-3.3-70b-versatile")
    end

    it "incluye Groq si la ENV está seteada" do
      ENV["GROQ_API_KEY"] = "x"
      expect(described_class.cloud_model_ids).to include("llama-3.3-70b-versatile")
    ensure
      ENV.delete("GROQ_API_KEY")
    end
  end

  describe ".provider_for" do
    it "devuelve el provider o nil" do
      expect(described_class.provider_for("llama-3.3-70b-versatile")).to eq("groq")
      expect(described_class.provider_for("inexistente")).to be_nil
    end
  end

  describe ".tier_of" do
    it "advanced/intermediate/basic para cloud, nil para Ollama" do
      expect(described_class.tier_of("llama-3.3-70b-versatile")).to eq(:advanced)
      expect(described_class.tier_of("openai/gpt-oss-20b")).to eq(:intermediate)
      expect(described_class.tier_of("allam-2-7b")).to eq(:basic)
      expect(described_class.tier_of("llama3.2:3b")).to be_nil
    end
  end
end
