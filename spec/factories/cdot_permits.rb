# frozen_string_literal: true

FactoryBot.define do
  factory :cdot_permit, class: "CdotPermit" do
    sequence(:unique_key) { |n| (1_000_000 + n).to_s }
    application_number { "APP-12345" }
    application_status { "Open" }
    application_start_date { 3.days.from_now }
    application_end_date { 10.days.from_now }
    application_expire_date { 10.days.from_now }
    street_number_from { 3300 }
    street_number_to { 3350 }
    direction { "N" }
    street_name { "CALIFORNIA" }
    suffix { "AVE" }
    ward { 28 }
    latitude { 41.885000 }
    longitude { -87.706000 }
    data_synced_at { Time.current }

    after(:build) do |permit|
      if permit.latitude.present? && permit.longitude.present? && permit.location.nil?
        geo = RGeo::Geographic.spherical_factory(srid: 4326)
        permit.location = geo.point(permit.longitude.to_f, permit.latitude.to_f)
      end
    end
  end
end
