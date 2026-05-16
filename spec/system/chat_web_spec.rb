require "rails_helper"

# System specs (Capybara + Cuprite headless Chrome). Cubren los flujos que
# antes solo se podían tocar a mano: usuario tipea en el form del chat web,
# el browser ve la respuesta vía Turbo Streams.
#
# Lo que verificamos acá es la "promesa" del refactor: el AI no hace solo,
# es Rails quien ejecuta las acciones reales. Ningún test acá mockea al AI
# para probar que el AI dijo X — testeamos que dado el input X, Rails hizo Y.

RSpec.describe "Web chat", type: :system do
  let(:conversation) { create(:conversation) }
  let(:mock_client)  { instance_double(Ai::RubyLlmClient) }

  before do
    allow(OllamaModels).to receive(:installed).and_return([])
    allow(Ai::Dispatcher).to receive(:for).and_return(mock_client)
    allow(mock_client).to receive(:chat).and_return(
      Dry::Monads::Success(AiResponse.new(content: "ok", model: "m", provider: "p"))
    )
    allow(mock_client).to receive(:stream) do |**_kwargs|
      Dry::Monads::Success(AiResponse.new(content: "ok", model: "m", provider: "p"))
    end
  end

  def send_message(text)
    fill_in "message[content]", with: text
    click_button "Enviar"
  end

  describe "slash commands desde el web" do
    it "/dispositivos lista los devices sin tocar al AI" do
      create(:device, device_id: "esp32_riego", name: "Riego")

      visit conversation_path(conversation)
      send_message "/dispositivos"

      expect(page).to have_content("Riego")
      expect(page).to have_content("esp32_riego")
      expect(mock_client).not_to have_received(:chat)
      expect(mock_client).not_to have_received(:stream)
    end

    it "/zona Buenos Aires persiste la zona y muestra confirmación" do
      visit conversation_path(conversation)
      send_message "/zona Buenos Aires"

      expect(page).to have_content(/configurada/i)
      expect(Setting.get("user_timezone")).to eq("Buenos Aires")
    end
  end

  describe "intent router determinístico" do
    it "'qué hora es' responde con la hora real desde Ruby, no del AI" do
      Setting.set("user_timezone", "America/Argentina/Buenos_Aires")

      visit conversation_path(conversation)
      send_message "qué hora es"

      expect(page).to have_content(/Son las \d{2}:\d{2}/)
      expect(mock_client).not_to have_received(:chat)
      expect(mock_client).not_to have_received(:stream)
    end

    it "'cómo están los dispositivos' muestra la lista REAL, no inventos del AI" do
      create(:device, device_id: "esp32_riego",     name: "Riego")
      create(:device, device_id: "esp32_cerradura", name: "Cerradura")

      visit conversation_path(conversation)
      send_message "cómo están los dispositivos"

      expect(page).to have_content("Riego")
      expect(page).to have_content("Cerradura")
      expect(mock_client).not_to have_received(:chat)
      expect(mock_client).not_to have_received(:stream)
    end
  end

  describe "tool calls del AI ejecutados por Rails" do
    it "AI devuelve create_reminder JSON → Rails crea el Reminder en la DB" do
      iso = 5.minutes.from_now.utc.iso8601
      tool_json = %({"tool":"create_reminder","scheduled_for":"#{iso}","message":"llamar al doctor","kind":"notify","device_id":null})

      allow(mock_client).to receive(:stream) do |**_kwargs|
        Dry::Monads::Success(AiResponse.new(content: tool_json, model: "m", provider: "p"))
      end

      visit conversation_path(conversation)

      expect {
        send_message("recordame en 5 minutos llamar al doctor")
        # esperar a que el create se complete server-side
        Timeout.timeout(5) { sleep 0.1 until Reminder.exists? }
      }.to change(Reminder, :count).by(1)

      expect(Reminder.last.message).to eq("llamar al doctor")
    end

    it "AI omite el tool pero el user pidió un recordatorio → fallback crea el Reminder igual" do
      allow(mock_client).to receive(:stream) do |**_kwargs|
        Dry::Monads::Success(AiResponse.new(content: "¡Claro! Te aviso en 30 minutos.", model: "m", provider: "p"))
      end

      visit conversation_path(conversation)

      expect {
        send_message("podrías recordarme en 30 minutos algo importante")
        Timeout.timeout(5) { sleep 0.1 until Reminder.exists? }
      }.to change(Reminder, :count).by(1)
    end
  end

  describe "validación básica" do
    it "no acepta mensajes vacíos" do
      visit conversation_path(conversation)
      send_message ""
      # El form de Hotwire no crea nada cuando el contenido está vacío
      expect(conversation.messages.count).to eq(0)
    end
  end
end
