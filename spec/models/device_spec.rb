require "rails_helper"

RSpec.describe Device, type: :model do
  subject(:device) { build(:device) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:device_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:system_prompt) }
    it "no permite device_id duplicados" do
      existing = create(:device)
      duplicate = build(:device, device_id: existing.device_id)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:device_id]).to be_present
    end
    it { is_expected.to validate_inclusion_of(:security_level).in_array(%w[normal high]) }

    it "es válido con atributos correctos" do
      expect(device).to be_valid
    end
  end

  describe "token" do
    it "genera un token al crear" do
      device.save!
      expect(device.token).to be_present
      expect(device.token.length).to eq(64)
    end

    it "los tokens son únicos entre dispositivos" do
      d1 = create(:device)
      d2 = create(:device)
      expect(d1.token).not_to eq(d2.token)
    end

    it "no sobreescribe un token existente" do
      device.token = "tok_existente"
      device.save!
      expect(device.token).to eq("tok_existente")
    end
  end

  describe "#high_security?" do
    it "devuelve true cuando security_level es high" do
      expect(build(:device, :high_security)).to be_high_security
    end

    it "devuelve false cuando security_level es normal" do
      expect(build(:device)).not_to be_high_security
    end
  end
end
