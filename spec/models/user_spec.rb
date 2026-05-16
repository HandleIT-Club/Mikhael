require "rails_helper"

RSpec.describe User do
  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }

    it "rechaza emails inválidos" do
      user = build(:user, email: "no-es-un-email")
      expect(user).not_to be_valid
    end

    it "normaliza email a minúscula y sin spaces" do
      user = create(:user, email: "  Foo@EXAMPLE.test  ")
      expect(user.email).to eq("foo@example.test")
    end

    it "exige email único (case-insensitive)" do
      create(:user, email: "alice@example.test")
      dup = build(:user, email: "ALICE@example.test")
      expect(dup).not_to be_valid
    end

    it "exige password de mínimo 12 caracteres" do
      user = build(:user, password: "short")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "exige telegram_chat_id único si está presente" do
      create(:user, :with_telegram, telegram_chat_id: "12345")
      dup = build(:user, telegram_chat_id: "12345")
      expect(dup).not_to be_valid
    end
  end

  describe "api_token (HMAC digest en DB, plain solo en memoria)" do
    it "se autogenera con 256 bits (64 hex chars) en creación" do
      user = create(:user)
      expect(user.api_token).to be_present
      expect(user.api_token.length).to eq(64)
      expect(user.api_token).to match(/\A[a-f0-9]{64}\z/)
    end

    it "el digest es único" do
      a = create(:user)
      b = build(:user)
      b.api_token_digest = a.api_token_digest
      expect(b).not_to be_valid
    end

    it "regenerate_api_token! cambia el token y devuelve el plain nuevo" do
      user = create(:user)
      old_digest = user.api_token_digest
      new_plain  = user.regenerate_api_token!
      expect(user.api_token_digest).not_to eq(old_digest)
      expect(new_plain).to match(/\A[a-f0-9]{64}\z/)
      expect(user.api_token).to eq(new_plain)
    end

    it "find_by_api_token resuelve el user por el plain (vía HMAC)" do
      user = create(:user)
      expect(described_class.find_by_api_token(user.api_token)).to eq(user)
    end

    it "find_by_api_token devuelve nil con plain incorrecto" do
      create(:user)
      expect(described_class.find_by_api_token("a" * 64)).to be_nil
    end

    it "find_by_api_token devuelve nil con plain vacío" do
      expect(described_class.find_by_api_token("")).to be_nil
      expect(described_class.find_by_api_token(nil)).to be_nil
    end

    it "el plain NO se persiste — el user recargado no lo conoce" do
      user = create(:user)
      reloaded = described_class.find(user.id)
      expect(reloaded.api_token).to be_nil
      expect(reloaded.api_token_digest).to be_present
    end
  end

  describe "associations" do
    it "tiene many conversations, reminders, settings" do
      user = create(:user)
      create(:conversation, user: user)
      create(:reminder, user: user)
      expect(user.conversations.count).to eq(1)
      expect(user.reminders.count).to eq(1)
    end

    it "destroy cascade borra conversaciones, recordatorios y settings" do
      user = create(:user)
      create(:conversation, user: user)
      create(:reminder, user: user)
      Setting.set_for(user, "user_timezone", "Madrid")

      expect { user.destroy }
        .to change(Conversation, :count).by(-1)
        .and change(Reminder, :count).by(-1)
        .and change(Setting, :count).by(-1)
    end
  end

  describe "has_secure_password" do
    it "guarda password como digest, no en plain" do
      user = create(:user, password: "supersecret123456")
      expect(user.password_digest).to be_present
      expect(user.password_digest).not_to eq("supersecret123456")
    end

    it "authenticate retorna el user con password correcta" do
      user = create(:user, password: "supersecret123456")
      expect(user.authenticate("supersecret123456")).to eq(user)
    end

    it "authenticate retorna false con password incorrecta" do
      user = create(:user, password: "supersecret123456")
      expect(user.authenticate("incorrecta")).to be(false)
    end
  end

  describe ".create_admin!" do
    it "crea con admin=true" do
      user = described_class.create_admin!(email: "admin@example.test", password: "supersecret123456")
      expect(user).to be_admin
    end
  end
end
