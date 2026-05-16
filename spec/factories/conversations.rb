FactoryBot.define do
  factory :conversation do
    user
    title    { Faker::Lorem.sentence(word_count: 3) }
    provider { "groq" }
    model_id { "llama-3.3-70b-versatile" }

    trait :ollama do
      provider { "ollama" }
      model_id { "llama3.2:3b" }
    end
  end
end
