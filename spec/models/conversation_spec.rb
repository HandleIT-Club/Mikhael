require "rails_helper"

RSpec.describe Conversation, type: :model do
  subject(:conversation) { build(:conversation) }

  describe "associations" do
    it { is_expected.to have_many(:messages).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:model_id) }
    it { is_expected.to validate_inclusion_of(:provider).in_array(%w[ollama groq]) }
    it { is_expected.to validate_inclusion_of(:model_id).in_array(Conversation::MODELS.keys) }
  end

  describe "defaults" do
    it "sets a title before validation if blank" do
      conversation.title = nil
      conversation.valid?
      expect(conversation.title).to be_present
    end

    it "infiere el provider desde el model_id" do
      conv = Conversation.new(model_id: "gemma2-9b-it")
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
