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
    allow(mock_client).to receive(:stream).and_return(Dry::Monads::Success(ai_response))
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

      it "usa #chat cuando no se pasa on_chunk" do
        operation.call(conversation: conversation, content: "Hola")
        expect(mock_client).to have_received(:chat)
        expect(mock_client).not_to have_received(:stream)
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
        allow(mock_client).to receive(:stream).and_return(Dry::Monads::Failure(:ai_error))
      end

      it "retorna Failure y no persiste la respuesta del asistente" do
        result = operation.call(conversation: conversation, content: "Hola")
        expect(result).to be_failure
        expect(conversation.messages.where(role: "assistant").count).to eq(0)
      end
    end

    context "con on_chunk (streaming)" do
      before do
        allow(mock_client).to receive(:stream) do |messages:, model:, &block|
          block.call("Hola ")
          block.call("mundo")
          Dry::Monads::Success(ai_response)
        end
      end

      it "llama al método stream del cliente (no chat)" do
        operation.call(conversation: conversation, content: "Hola", on_chunk: ->(_) { })
        expect(mock_client).to have_received(:stream)
        expect(mock_client).not_to have_received(:chat)
      end

      it "hace yield de cada chunk al on_chunk" do
        received = []
        operation.call(conversation: conversation, content: "Hola", on_chunk: ->(chunk) { received << chunk })
        expect(received).to eq([ "Hola ", "mundo" ])
      end

      it "persiste la respuesta al terminar" do
        expect {
          operation.call(conversation: conversation, content: "Hola", on_chunk: ->(_) { })
        }.to change { conversation.messages.where(role: "assistant").count }.by(1)
      end

      context "cuando user_message ya fue guardado externamente" do
        let!(:pre_saved) { conversation.messages.create!(role: "user", content: "Hola") }

        it "no duplica el mensaje del usuario" do
          expect {
            operation.call(conversation: conversation, content: "Hola",
                           user_message: pre_saved, on_chunk: ->(_) { })
          }.not_to change { conversation.messages.where(role: "user").count }
        end
      end
    end

    context "fallback de streaming a no-streaming" do
      before do
        allow(ModelSelector).to receive(:mark_rate_limited)
        allow(ModelSelector).to receive(:next_available).and_return("llama-3.1-8b-instant")
        allow_any_instance_of(Conversation).to receive(:update!).and_call_original
        allow(mock_client).to receive(:stream).and_return(Dry::Monads::Failure(:rate_limited))
        allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
        # Permitir modelo del fallback aunque no esté en la lista estándar
        allow_any_instance_of(Conversation).to receive(:update!).with(model_id: "llama-3.1-8b-instant")
          .and_return(true)
      end

      it "usa chat (no streaming) en el retry tras fallo de stream" do
        operation.call(conversation: conversation, content: "Hola", on_chunk: ->(_) { })
        expect(mock_client).to have_received(:stream)
        expect(mock_client).to have_received(:chat)
      end

      it "retorna Success con la respuesta del fallback" do
        result = operation.call(conversation: conversation, content: "Hola", on_chunk: ->(_) { })
        expect(result).to be_success
      end
    end
  end
end
