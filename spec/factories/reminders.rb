FactoryBot.define do
  factory :reminder do
    user
    message       { "Revisar el riego" }
    scheduled_for { 2.hours.from_now }
    kind          { "notify" }
    device_id     { nil }
    executed_at   { nil }

    trait :query_device do
      kind      { "query_device" }
      device_id { association(:device).id }
    end

    trait :executed do
      executed_at { 1.hour.ago }
    end

    trait :past do
      scheduled_for { 1.hour.ago }
    end
  end
end
