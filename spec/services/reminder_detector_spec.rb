require "rails_helper"

RSpec.describe ReminderDetector do
  subject(:detector) { described_class.new }

  let(:mock_client) { instance_double(Ai::RubyLlmClient) }

  before do
    allow(OllamaModels).to receive(:installed).and_return([])
    allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
  end

  def stub_ai(json)
    allow(mock_client).to receive(:chat).and_return(
      Dry::Monads::Success(AiResponse.new(content: json.to_json, model: "m", provider: "p"))
    )
  end

  describe "#call" do
    context "cuando el mensaje es un recordatorio simple (notify)" do
      before do
        stub_ai(
          "is_reminder"   => true,
          "scheduled_for" => 2.hours.from_now.iso8601,
          "message"       => "Revisar el riego",
          "kind"          => "notify",
          "device_id"     => nil
        )
      end

      it "detecta correctamente la intención de recordatorio" do
        result = detector.call("Recordame en 2 horas revisar el riego")
        expect(result).to be_success
        expect(result.value!["is_reminder"]).to be true
      end

      it "convierte scheduled_for a un objeto Time" do
        result = detector.call("Recordame en 2 horas revisar el riego")
        expect(result.value!["scheduled_for"]).to be_a(Time)
      end

      it "preserva el mensaje y kind" do
        result = detector.call("Recordame en 2 horas revisar el riego")
        data = result.value!
        expect(data["message"]).to eq("Revisar el riego")
        expect(data["kind"]).to eq("notify")
        expect(data["device_id"]).to be_nil
      end
    end

    context "cuando el mensaje involucra un dispositivo (query_device)" do
      let(:device) { create(:device) }

      before do
        stub_ai(
          "is_reminder"   => true,
          "scheduled_for" => 1.day.from_now.change(hour: 8).iso8601,
          "message"       => "Cómo está el riego",
          "kind"          => "query_device",
          "device_id"     => device.id
        )
      end

      it "detecta kind=query_device y device_id" do
        result = detector.call("Mañana a las 8 preguntale al ESP32 del riego cómo está")
        data = result.value!
        expect(data["kind"]).to eq("query_device")
        expect(data["device_id"]).to eq(device.id)
      end
    end

    context "cuando el mensaje NO es un recordatorio" do
      before do
        stub_ai("is_reminder" => false)
      end

      it "devuelve is_reminder: false" do
        result = detector.call("Cuál es la capital de Francia?")
        expect(result).to be_success
        expect(result.value!["is_reminder"]).to be false
      end
    end

    context "cuando el AI no puede determinar la hora" do
      before do
        stub_ai("is_reminder" => false, "needs_clarification" => true)
      end

      it "devuelve needs_clarification: true" do
        result = detector.call("Avisame el lunes")
        expect(result).to be_success
        expect(result.value!["needs_clarification"]).to be true
      end
    end

    context "cuando el AI falla" do
      before do
        allow(mock_client).to receive(:chat).and_return(Dry::Monads::Failure(:ai_error))
      end

      it "retorna Failure(:ai_error)" do
        result = detector.call("Recordame algo")
        expect(result).to be_failure
        expect(result.failure).to eq(:ai_error)
      end
    end

    context "cuando el AI devuelve JSON inválido" do
      before do
        allow(mock_client).to receive(:chat).and_return(
          Dry::Monads::Success(AiResponse.new(content: "no es json", model: "m", provider: "p"))
        )
      end

      it "retorna Failure(:invalid_json)" do
        result = detector.call("Recordame algo")
        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_json)
      end
    end

    context "cuando el AI embebe el JSON dentro de texto extra" do
      before do
        json_in_text = %(Aquí el análisis: {"is_reminder":true,"scheduled_for":"#{2.minutes.from_now.utc.iso8601}","message":"irse a dormir","kind":"notify","device_id":null} Eso es todo.)
        allow(mock_client).to receive(:chat).and_return(
          Dry::Monads::Success(AiResponse.new(content: json_in_text, model: "m", provider: "p"))
        )
      end

      it "extrae el JSON correctamente y detecta el recordatorio" do
        result = detector.call("Recordame en 2 minutos de irme a dormir")
        expect(result).to be_success
        expect(result.value!["is_reminder"]).to be true
        expect(result.value!["scheduled_for"]).to be_a(Time)
      end
    end

    context "cuando el AI devuelve scheduled_for en formato no parseable" do
      before do
        stub_ai(
          "is_reminder"   => true,
          "scheduled_for" => "en dos minutos",   # lenguaje natural, no ISO8601
          "message"       => "dormir",
          "kind"          => "notify",
          "device_id"     => nil
        )
      end

      it "lo trata como needs_clarification en vez de caer al chat" do
        result = detector.call("Recordame en 2 minutos de irme a dormir")
        expect(result).to be_success
        expect(result.value!["needs_clarification"]).to be true
      end
    end
  end
end
