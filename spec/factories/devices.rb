FactoryBot.define do
  factory :device do
    device_id      { "dev_#{SecureRandom.hex(4)}" }
    name           { Faker::Device.model_name }
    system_prompt  { "Controlá el dispositivo. Respondé siempre en JSON." }
    security_level { "normal" }

    trait :high_security do
      security_level { "high" }
    end
  end
end
