# frozen_string_literal: true

FactoryBot.define do
  factory :sweep do
    area_id { SecureRandom.uuid }
    date_1 { Date.tomorrow }
  end
end