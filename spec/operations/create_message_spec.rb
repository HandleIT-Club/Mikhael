require "rails_helper"

RSpec.describe CreateMessage do
  subject(:operation) { described_class.new }

  let(:conversation) { create(:conversation) }
  let(:ai_response)  { AiResponse.new(content: "Respuesta de prueba", model: "llama-3.3-70b-versatile", provider: "groq") }
  let(:mock_client)  { instance_double(Ai::RubyLlmClient) }

  before do
    allow(OllamaModels).to receive(:installed).and_return([])
    allow(Ai::Dispatcher).to receive(:for).with("groq").and_return(mock_client)
    allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
  end

  describe "#call" do
    context "con input válido" do
      it "retorna Success con el AiResponse" do
        result = operation.call(conversation: conversation, content: "Hola")
        expect(result).to be_success
        expect(result.value!).to eq(ai_response)
      end

      it "persiste el mensaje del usuario" do
        expect {
          operation.call(conversation: conversation, content: "Hola")
        }.to change { conversation.messages.where(role: "user").count }.by(1)
      end

      it "persiste la respuesta del asistente" do
        expect {
          operation.call(conversation: conversation, content: "Hola")
        }.to change { conversation.messages.where(role: "assistant").count }.by(1)
      end
    end

    context "con input inválido" do
      it "retorna Failure cuando el contenido está vacío" do
        result = operation.call(conversation: conversation, content: "   ")
        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_input)
      end
    end

    context "cuando la IA falla" do
      before do
        allow(mock_client).to receive(:chat).and_return(Dry::Monads::Failure(:ai_error))
      end

      it "retorna Failure y no persiste la respuesta del asistente" do
        result = operation.call(conversation: conversation, content: "Hola")
        expect(result).to be_failure
        expect(conversation.messages.where(role: "assistant").count).to eq(0)
      end
    end
  end
end
