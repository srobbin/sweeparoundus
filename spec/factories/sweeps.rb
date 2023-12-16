# frozen_string_literal: true

FactoryBot.define do
  factory :sweep do
    area { create :area }
    date_1 { Date.tomorrow }
  end
end