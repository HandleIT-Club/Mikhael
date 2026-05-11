FactoryBot.define do
  factory :conversation do
    title    { Faker::Lorem.sentence(word_count: 3) }
    provider { "ollama" }
    model_id { "llama3.2:3b" }

    trait :groq do
      provider { "groq" }
      model_id { "gemma2-9b-it" }
    end
  end
end
