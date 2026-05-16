require "rails_helper"

RSpec.describe Ai::Cooldown do
  before { Rails.cache.clear }

  it "marca y detecta cooldown" do
    described_class.mark("llama-3.3-70b-versatile")
    expect(described_class.active?("llama-3.3-70b-versatile")).to be(true)
  end

  it "no afecta otros modelos" do
    described_class.mark("llama-3.3-70b-versatile")
    expect(described_class.active?("cerebras/llama-3.3-70b")).to be(false)
  end

  it "expira tras DURATION" do
    described_class.mark("llama-3.3-70b-versatile")
    travel(described_class::DURATION + 1.second) do
      expect(described_class.active?("llama-3.3-70b-versatile")).to be(false)
    end
  end
end
