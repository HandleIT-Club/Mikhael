require "rails_helper"

RSpec.describe "MemoriesController", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }

  before do
    allow(OllamaModels).to receive(:installed).and_return([])
    sign_in_as(user)
  end

  describe "GET /memories" do
    it "lista las memories del usuario" do
      create(:memory, user: user, summary: "Mi memoria personal")
      get memories_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mi memoria personal")
    end

    it "no lista memories de otro usuario" do
      create(:memory, user: other_user, summary: "Memoria ajena")
      get memories_path
      expect(response.body).not_to include("Memoria ajena")
    end

    it "filtra por keyword cuando se pasa ?q=" do
      create(:memory, user: user, keywords: "rails, rutas", summary: "Sobre Rails")
      create(:memory, user: user, keywords: "python, django", summary: "Sobre Python")
      get memories_path, params: { q: "rails" }
      expect(response.body).to include("Sobre Rails")
      expect(response.body).not_to include("Sobre Python")
    end
  end

  describe "DELETE /memories/:id" do
    it "permite borrar una memory propia" do
      memory = create(:memory, user: user)
      expect { delete memory_path(memory) }.to change(Memory, :count).by(-1)
      expect(response).to redirect_to(memories_path)
    end

    it "no permite borrar una memory de otro usuario" do
      memory = create(:memory, user: other_user)
      expect { delete memory_path(memory) }.not_to change(Memory, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
