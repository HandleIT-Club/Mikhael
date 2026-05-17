require "rails_helper"

RSpec.describe GenerateMemoryJob do
  let(:user)         { create(:user) }
  let(:conversation) { create(:conversation, user: user) }
  let(:mock_client)  { instance_double(Ai::RubyLlmClient) }
  let(:ai_response)  { AiResponse.new(content: '{"summary":"El usuario configuró Rails.","keywords":"rails, config, servidor"}', model: "m", provider: "p") }

  before do
    allow(OllamaModels).to receive(:installed).and_return([])
    stub_ai_provider!
    allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
    allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
  end

  def create_messages(count)
    count.times do |i|
      role = i.even? ? "user" : "assistant"
      create(:message, conversation: conversation, role: role, content: "Mensaje #{i}")
    end
  end

  describe "#perform" do
    context "cuando la conversación no existe" do
      it "no lanza error" do
        expect { described_class.perform_now(999_999) }.not_to raise_error
      end
    end

    context "cuando la conversación tiene menos de TRIGGER_COUNT mensajes" do
      before { create_messages(Memory::TRIGGER_COUNT - 1) }

      it "no crea ninguna Memory" do
        expect { described_class.perform_now(conversation.id) }.not_to change(Memory, :count)
      end

      it "no llama al AI" do
        described_class.perform_now(conversation.id)
        expect(mock_client).not_to have_received(:chat)
      end
    end

    context "cuando la conversación tiene TRIGGER_COUNT mensajes" do
      before { create_messages(Memory::TRIGGER_COUNT) }

      it "crea una Memory" do
        expect { described_class.perform_now(conversation.id) }.to change(Memory, :count).by(1)
      end

      it "persiste el resumen y las keywords del AI" do
        described_class.perform_now(conversation.id)
        memory = Memory.last
        expect(memory.summary).to eq("El usuario configuró Rails.")
        expect(memory.keywords).to eq("rails, config, servidor")
      end

      it "asocia la Memory al user y a la conversación" do
        described_class.perform_now(conversation.id)
        memory = Memory.last
        expect(memory.user).to eq(user)
        expect(memory.conversation).to eq(conversation)
      end

      it "setea context_cutoff_at en la conversación" do
        expect { described_class.perform_now(conversation.id) }
          .to change { conversation.reload.context_cutoff_at }.from(nil)
      end
    end

    context "cuando el AI devuelve JSON inválido" do
      let(:ai_response) { AiResponse.new(content: "esto no es JSON", model: "m", provider: "p") }

      before { create_messages(Memory::TRIGGER_COUNT) }

      it "no crea ninguna Memory" do
        expect { described_class.perform_now(conversation.id) }.not_to change(Memory, :count)
      end

      it "no setea context_cutoff_at" do
        described_class.perform_now(conversation.id)
        expect(conversation.reload.context_cutoff_at).to be_nil
      end
    end

    context "cuando el AI falla" do
      before do
        create_messages(Memory::TRIGGER_COUNT)
        allow(mock_client).to receive(:chat).and_return(Dry::Monads::Failure(:rate_limited))
      end

      it "no crea ninguna Memory" do
        expect { described_class.perform_now(conversation.id) }.not_to change(Memory, :count)
      end
    end
  end
end
