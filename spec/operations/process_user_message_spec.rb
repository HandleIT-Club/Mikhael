require "rails_helper"

RSpec.describe ProcessUserMessage do
  let(:user)         { create(:user) }
  let(:conversation) { create(:conversation, user: user) }
  let(:broadcaster)  { instance_spy(NullChatBroadcaster) }
  let(:mock_client)  { instance_double(Ai::RubyLlmClient) }
  let(:ai_response)  { AiResponse.new(content: "¡Hola!", model: "m", provider: "p") }

  subject(:operation) do
    described_class.new(conversation: conversation, user: user, broadcaster: broadcaster)
  end

  before do
    allow(OllamaModels).to receive(:installed).and_return([])
    stub_ai_provider!
    allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
    allow(mock_client).to receive(:chat).and_return(Dry::Monads::Success(ai_response))
    allow(mock_client).to receive(:stream).and_return(Dry::Monads::Success(ai_response))
  end

  describe "input vacío" do
    it "retorna Failure(:invalid_input)" do
      expect(operation.call("   ")).to be_failure
      expect(operation.call("   ").failure).to eq(:invalid_input)
    end

    it "no persiste ningún mensaje" do
      expect { operation.call("") }.not_to change(conversation.messages, :count)
    end
  end

  describe "slash command" do
    it "responde con el reply del CommandRouter y no llama al AI" do
      create(:device, device_id: "esp32_riego", name: "Riego")
      operation.call("/dispositivos")
      expect(mock_client).not_to have_received(:stream)
      expect(broadcaster).to have_received(:append_message).at_least(:twice) # user + assistant
    end

    it "retorna Outcome con kind=:deterministic" do
      result = operation.call("/start")
      expect(result).to be_success
      expect(result.value!.kind).to eq(:deterministic)
    end
  end

  describe "intent router" do
    it "'qué hora es' responde sin tocar al AI" do
      operation.call("qué hora es")
      expect(mock_client).not_to have_received(:stream)
    end
  end

  describe "chat normal con AI" do
    let(:ai_response) { AiResponse.new(content: "Respuesta", model: "m", provider: "p") }

    it "muestra placeholder, streamea chunks y reemplaza al final" do
      operation.call("hola")
      expect(broadcaster).to have_received(:show_streaming_placeholder)
      expect(broadcaster).to have_received(:replace_streaming_placeholder)
    end

    it "retorna Outcome con kind=:ai" do
      result = operation.call("hola")
      expect(result.value!.kind).to eq(:ai)
    end
  end

  describe "AI falla" do
    before do
      allow(mock_client).to receive(:stream).and_return(Dry::Monads::Failure(:ai_error))
    end

    it "remueve el placeholder y retorna Failure(:ai_error)" do
      result = operation.call("hola")
      expect(result).to be_failure
      expect(broadcaster).to have_received(:remove_streaming_placeholder)
    end
  end

  describe "inyección de memorias" do
    context "primer mensaje de la conversación" do
      it "busca memorias relevantes e inyecta las que matchean" do
        memory = create(:memory, user: user, keywords: "rails, rutas, api")
        context_spy = instance_spy(AssistantContext)
        allow(AssistantContext).to receive(:for).and_return(context_spy)
        allow(context_spy).to receive(:build).and_return("prompt")
        allow(context_spy).to receive(:primer).and_return([])

        operation.call("cuéntame sobre rails y rutas")

        expect(context_spy).to have_received(:build).with(memories: [ memory ])
      end

      it "no inyecta memories si no hay matches" do
        create(:memory, user: user, keywords: "python, django, flask")
        context_spy = instance_spy(AssistantContext)
        allow(AssistantContext).to receive(:for).and_return(context_spy)
        allow(context_spy).to receive(:build).and_return("prompt")
        allow(context_spy).to receive(:primer).and_return([])

        operation.call("hello world")

        expect(context_spy).to have_received(:build).with(memories: [])
      end
    end

    context "conversación con mensajes previos" do
      before { create(:message, conversation: conversation, role: "user", content: "mensaje previo") }

      it "no busca memorias (no es el primer mensaje)" do
        allow(Memory).to receive(:relevant_for).and_call_original
        operation.call("segundo mensaje")
        expect(Memory).not_to have_received(:relevant_for)
      end
    end
  end

  describe "generación de memoria automática" do
    before { allow(GenerateMemoryJob).to receive(:perform_later) }

    context "cuando la conversación alcanza TRIGGER_COUNT mensajes" do
      before do
        # Creamos TRIGGER_COUNT - 2 mensajes para que el turno actual (user + assistant) llegue exactamente a TRIGGER_COUNT
        (Memory::TRIGGER_COUNT - 2).times do |i|
          create(:message, conversation: conversation, role: i.even? ? "user" : "assistant", content: "msg#{i}")
        end
      end

      it "encola GenerateMemoryJob" do
        operation.call("mensaje que llega al límite")
        expect(GenerateMemoryJob).to have_received(:perform_later).with(conversation.id)
      end
    end

    context "cuando la conversación tiene menos de TRIGGER_COUNT mensajes" do
      it "no encola GenerateMemoryJob" do
        operation.call("mensaje normal")
        expect(GenerateMemoryJob).not_to have_received(:perform_later)
      end
    end
  end

  describe "tool call con dedup silencioso (Reminder duplicado)" do
    let(:future_iso) { 5.minutes.from_now.utc.iso8601 }
    let(:tool_json)  { %({"tool":"create_reminder","scheduled_for":"#{future_iso}","message":"dormir","kind":"notify","device_id":null}) }
    let(:ai_response) { AiResponse.new(content: tool_json, model: "m", provider: "p") }

    it "retorna kind=:dedup en la segunda llamada idéntica" do
      operation.call("recordame en 5 min dormir") # crea
      second = operation.call("recordame en 5 min dormir") # dedup
      expect(second.value!.kind).to eq(:dedup)
    end
  end
end
