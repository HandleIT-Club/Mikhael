require "rails_helper"

RSpec.describe Ai::FallbackChain do
  before do
    Ai::ModelRegistry.reset!
    Rails.cache.clear
    allow(OllamaModels).to receive(:installed).and_return([])
  end

  describe "sin ninguna API key seteada y sin Ollama" do
    before do
      ENV.delete("GROQ_API_KEY")
      ENV.delete("CEREBRAS_API_KEY")
      ENV.delete("SAMBANOVA_API_KEY")
    end

    it "first_available es nil" do
      expect(described_class.first_available).to be_nil
    end
  end

  describe "con GROQ_API_KEY seteada" do
    before { ENV["GROQ_API_KEY"] = "x" }
    after  { ENV.delete("GROQ_API_KEY") }

    it "first_available devuelve un Groq" do
      expect(described_class.first_available).to start_with("llama").or include("openai").or include("qwen")
    end

    it "salta el actual si está en cooldown" do
      first = described_class.first_available
      Ai::Cooldown.mark(first)
      expect(described_class.first_available).not_to eq(first)
    end

    it "next_available recorre hacia delante" do
      first  = described_class.first_available
      second = described_class.next_available(first)
      expect(second).to be_present
      expect(second).not_to eq(first)
    end
  end

  describe "con Ollama instalado" do
    before { allow(OllamaModels).to receive(:installed).and_return([ "llama3.2:3b" ]) }

    it "first_available cae a Ollama si no hay cloud" do
      ENV.delete("GROQ_API_KEY")
      ENV.delete("CEREBRAS_API_KEY")
      ENV.delete("SAMBANOVA_API_KEY")
      expect(described_class.first_available).to eq("llama3.2:3b")
    end

    it "next_available_cloud no devuelve Ollama" do
      ENV["GROQ_API_KEY"] = "x"
      first = described_class.first_available
      Ai::Cooldown.mark(first)
      next_cloud = described_class.next_available_cloud(first)
      expect(next_cloud).not_to eq("llama3.2:3b")
    ensure
      ENV.delete("GROQ_API_KEY")
    end
  end
end
