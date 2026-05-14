FactoryBot.define do
  factory :message do
    conversation
    role    { "user" }
    content { Faker::Lorem.paragraph }

    trait :assistant do
      role { "assistant" }
    end

    trait :system do
      role    { "system" }
      content { "Eres un asistente útil." }
    end
  end
end
