require "rails_helper"

RSpec.describe Conversation, type: :model do
  subject(:conversation) { build(:conversation) }

  before do
    # Ollama no corre en tests — devolvemos lista vacía para que no falle la validación
    allow(OllamaModels).to receive(:installed).and_return([])
  end

  describe "associations" do
    it { is_expected.to have_many(:messages).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:model_id) }

    it "acepta modelos cloud válidos" do
      expect(conversation).to be_valid
    end

    it "rechaza model_id desconocido" do
      conversation.model_id = "modelo-inexistente"
      expect(conversation).not_to be_valid
    end

    it "fuerza el provider correcto aunque venga uno inconsistente" do
      conv = Conversation.new(model_id: "llama-3.3-70b-versatile", provider: "ollama")
      conv.valid?
      expect(conv.provider).to eq("groq")
    end
  end

  describe "defaults" do
    it "sets a title before validation if blank" do
      conversation.title = nil
      conversation.valid?
      expect(conversation.title).to be_present
    end

    it "infiere el provider desde el model_id" do
      conv = Conversation.new(model_id: "llama-3.3-70b-versatile")
      conv.valid?
      expect(conv.provider).to eq("groq")
    end
  end

  describe "#chat_messages" do
    let(:conversation) { create(:conversation) }

    it "excludes system messages" do
      create(:message, :system, conversation:)
      create(:message, conversation:)
      expect(conversation.chat_messages.map(&:role)).not_to include("system")
    end
  end
end
