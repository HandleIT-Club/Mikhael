FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.test" }
    password { "supersecret123456" }
    admin    { false }

    trait :admin do
      admin { true }
    end

    trait :with_telegram do
      sequence(:telegram_chat_id) { |n| "10000#{n}" }
    end
  end
end
