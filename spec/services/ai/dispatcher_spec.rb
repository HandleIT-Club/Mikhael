require "rails_helper"

RSpec.describe Ai::Dispatcher do
  describe ".for" do
    it "devuelve un RubyLlmClient para ollama" do
      expect(described_class.for("ollama")).to be_a(Ai::RubyLlmClient)
    end

    it "devuelve un RubyLlmClient para groq" do
      expect(described_class.for("groq")).to be_a(Ai::RubyLlmClient)
    end

    it "devuelve un CerebrasClient para cerebras" do
      expect(described_class.for("cerebras")).to be_a(Ai::CerebrasClient)
    end

    it "devuelve un SambaNovaClient para sambanova" do
      expect(described_class.for("sambanova")).to be_a(Ai::SambaNovaClient)
    end

    it "lanza ArgumentError para un provider desconocido" do
      expect { described_class.for("unknown") }.to raise_error(ArgumentError)
    end
  end
end
