require "rails_helper"

RSpec.describe "Users (admin CRUD)", type: :request do
  let(:admin)     { create(:user, :admin) }
  let(:non_admin) { create(:user) }

  before { sign_in_as(admin) }

  describe "POST /users" do
    let(:valid_params) do
      { user: { email: "nuevo@example.test", password: "supersecret123456", admin: "false" } }
    end

    it "crea un user nuevo" do
      expect { post users_path, params: valid_params }.to change(User, :count).by(1)
      expect(response).to redirect_to(settings_path)
    end

    it "deja el plain token en flash para mostrar una sola vez" do
      post users_path, params: valid_params
      expect(flash[:reveal_token]).to match(/\A[a-f0-9]{64}\z/)
      expect(flash[:reveal_user_id]).to eq(User.find_by(email: "nuevo@example.test").id)
    end

    it "rechaza email duplicado con alert" do
      create(:user, email: "dup@example.test")
      post users_path, params: { user: { email: "dup@example.test", password: "supersecret123456" } }
      expect(response).to redirect_to(settings_path)
      follow_redirect!
      expect(response.body).to match(/ya está en uso|en uso|duplicate|invalido/i).or include("No se pudo crear")
    end

    it "rechaza password corto" do
      post users_path, params: { user: { email: "x@example.test", password: "corta" } }
      expect(User.find_by(email: "x@example.test")).to be_nil
    end

    it "no-admin: 403 / redirect" do
      sign_in_as(non_admin)
      expect { post users_path, params: valid_params }.not_to change(User, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /users/:id" do
    it "borra a otro user" do
      victim = create(:user)
      expect { delete user_path(victim) }.to change(User, :count).by(-1)
    end

    it "rechaza self-delete (lockout protection)" do
      expect { delete user_path(admin) }.not_to change(User, :count)
      expect(response).to redirect_to(settings_path)
      follow_redirect!
      expect(response.body).to match(/no podés/i)
    end
  end

  describe "PATCH /users/:id" do
    let(:target) { create(:user, admin: false) }

    it "toggle admin a true" do
      patch user_path(target), params: { user: { admin: "1" } }
      expect(target.reload).to be_admin
    end

    it "vincula telegram_chat_id" do
      patch user_path(target), params: { user: { admin: "0", telegram_chat_id: "99999" } }
      expect(target.reload.telegram_chat_id).to eq("99999")
    end

    it "rechaza removerse a sí mismo el admin (lockout)" do
      patch user_path(admin), params: { user: { admin: "0" } }
      expect(admin.reload).to be_admin
      expect(response).to redirect_to(settings_path)
      follow_redirect!
      expect(response.body).to match(/no podés/i)
    end
  end

  describe "POST /users/:id/regenerate_token" do
    let(:target) { create(:user) }

    it "regenera el token y deja el plain en flash" do
      old_digest = target.api_token_digest
      post regenerate_token_user_path(target)
      expect(target.reload.api_token_digest).not_to eq(old_digest)
      expect(flash[:reveal_token]).to match(/\A[a-f0-9]{64}\z/)
    end
  end
end
