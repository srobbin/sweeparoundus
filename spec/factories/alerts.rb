# frozen_string_literal: true

FactoryBot.define do
  factory :alert do
    email { Faker::Internet.email }
    area_id { SecureRandom.uuid }

    trait :confirmed do
      confirmed { true }
    end

    trait :unconfirmed do
      confirmed { false }
    end

    trait :with_address do
      street_address { Faker::Address.street_address }
    end
  end
end