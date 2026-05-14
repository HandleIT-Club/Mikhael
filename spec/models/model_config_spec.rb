require "rails_helper"

RSpec.describe ModelConfig do
  # Usamos un modelo cloud que siempre está disponible, sin depender de Ollama.
  let(:valid_model_id) { "llama-3.3-70b-versatile" }

  describe "validations" do
    subject { ModelConfig.new(model_id: valid_model_id, system_prompt: "Hola") }

    it { is_expected.to validate_presence_of(:model_id) }
    it { is_expected.to validate_presence_of(:system_prompt) }

    it "rechaza model_id que no está en los modelos disponibles" do
      config = ModelConfig.new(model_id: "inexistente", system_prompt: "x")
      expect(config).not_to be_valid
      expect(config.errors[:model_id]).to be_present
    end
  end

  describe ".prompt_for" do
    it "retorna el system_prompt configurado" do
      ModelConfig.create!(model_id: valid_model_id, system_prompt: "Sé breve.")
      expect(ModelConfig.prompt_for(valid_model_id)).to eq("Sé breve.")
    end

    it "retorna un default cuando el modelo no tiene config" do
      expect(ModelConfig.prompt_for(valid_model_id)).to include("Mikhael")
    end
  end
end
