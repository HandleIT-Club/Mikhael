require "rails_helper"

RSpec.describe Message, type: :model do
  subject(:message) { build(:message) }

  describe "associations" do
    it { is_expected.to belong_to(:conversation) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_inclusion_of(:role).in_array(%w[system user assistant]) }
  end
end
