# frozen_string_literal: true

FactoryBot.define do
  factory :alert do
    # `email` is a transient so existing `create(:alert, email: ...)` calls keep
    # working. It resolves to a Subscriber via find-or-create (NOT a fresh
    # association) so repeated emails reuse one subscriber instead of tripping
    # the subscribers.email unique index.
    transient do
      email { Faker::Internet.email }
    end

    subscriber do
      normalized = email.to_s.strip.downcase
      Subscriber.find_or_create_by!(email: normalized) if normalized.present?
    end

    area_id { SecureRandom.uuid }
    area { create :area }

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
