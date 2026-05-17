require "rails_helper"

RSpec.describe Memory, type: :model do
  before { allow(OllamaModels).to receive(:installed).and_return([]) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:conversation).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:summary) }
    it { is_expected.to validate_presence_of(:keywords) }
  end

  describe ".relevant_for" do
    let(:user)       { create(:user) }
    let(:other_user) { create(:user) }

    before do
      create(:memory, user: user,
        summary: "Hablamos sobre el sistema de riego automático.",
        keywords: "riego, automatico, esp32, agua")
      create(:memory, user: user,
        summary: "Configuramos las rutas de Rails para la API.",
        keywords: "rails, rutas, api, rest")
      create(:memory, user: other_user,
        summary: "Memory de otro usuario sobre riego.",
        keywords: "riego, agua")
    end

    it "devuelve memories que matchean keywords del mensaje" do
      result = Memory.relevant_for(user: user, message: "quiero configurar el riego")
      expect(result.map(&:keywords)).to include("riego, automatico, esp32, agua")
    end

    it "no devuelve memories de otro usuario" do
      result = Memory.relevant_for(user: user, message: "riego agua")
      expect(result.map(&:user_id)).to all(eq(user.id))
    end

    it "devuelve vacío cuando no hay matches" do
      result = Memory.relevant_for(user: user, message: "hola cómo estás")
      expect(result).to be_empty
    end

    it "devuelve vacío cuando el mensaje tiene solo palabras muy cortas" do
      result = Memory.relevant_for(user: user, message: "ok si no")
      expect(result).to be_empty
    end

    it "limita a MAX_RELEVANT resultados" do
      Memory::MAX_RELEVANT.next.times do
        create(:memory, user: user, keywords: "rails, rutas, api")
      end
      result = Memory.relevant_for(user: user, message: "necesito ayuda con rails")
      expect(result.count).to be <= Memory::MAX_RELEVANT
    end

    it "puede buscar sin conversación asociada (memoria manual)" do
      create(:memory, user: user, conversation: nil,
        summary: "Resumen manual de sesión.",
        keywords: "manual, sesion, resumen")
      result = Memory.relevant_for(user: user, message: "esta es una sesion manual")
      expect(result.map(&:keywords)).to include("manual, sesion, resumen")
    end
  end
end
