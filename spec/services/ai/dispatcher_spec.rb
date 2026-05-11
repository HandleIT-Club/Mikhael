require "rails_helper"

RSpec.describe Ai::Dispatcher do
  describe ".for" do
    it "returns OllamaClient for ollama" do
      expect(described_class.for("ollama")).to be_a(Ai::OllamaClient)
    end

    it "returns GroqClient for groq" do
      expect(described_class.for("groq")).to be_a(Ai::GroqClient)
    end

    it "raises ArgumentError for unknown provider" do
      expect { described_class.for("unknown") }.to raise_error(ArgumentError)
    end
  end
end
