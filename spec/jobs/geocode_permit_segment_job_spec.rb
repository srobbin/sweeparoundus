# frozen_string_literal: true

require "rails_helper"

RSpec.describe GeocodePermitSegmentJob, type: :job do
  let!(:permit) do
    create(:cdot_permit,
      street_number_from: 3300, street_number_to: 3350,
      direction: "N", street_name: "CALIFORNIA", suffix: "AVE",
      latitude: 41.885, longitude: -87.706)
  end

  let(:endpoint_a) { GeocodeAddress::Result.new(lat: 41.94142, lng: -87.69870) }
  let(:endpoint_b) { GeocodeAddress::Result.new(lat: 41.94284, lng: -87.69870) }

  describe "#perform" do
    context "when geocoding succeeds for both endpoints" do
      before do
        allow(GeocodeAddress).to receive(:new) do |address:|
          result = case address
                   when /\A3300\b/ then endpoint_a
                   when /\A3350\b/ then endpoint_b
                   end
          instance_double(GeocodeAddress, call: result, error_reason: nil)
        end
      end

      it "stores segment coordinates on the permit" do
        described_class.perform_now(permit.id)
        permit.reload

        expect(permit.segment_from_lat).to be_within(0.0001).of(41.94142)
        expect(permit.segment_from_lng).to be_within(0.0001).of(-87.69870)
        expect(permit.segment_to_lat).to be_within(0.0001).of(41.94284)
        expect(permit.segment_to_lng).to be_within(0.0001).of(-87.69870)
      end
    end

    context "when geocoding fails for both endpoints" do
      before do
        allow(GeocodeAddress).to receive(:new) do |address:|
          instance_double(GeocodeAddress, call: nil, error_reason: "geocode_status: ZERO_RESULTS")
        end
        allow(Sentry).to receive(:capture_message)
      end

      it "falls back to the permit's lat/lng" do
        described_class.perform_now(permit.id)
        permit.reload

        expect(permit.segment_from_lat).to be_within(0.001).of(41.885)
        expect(permit.segment_from_lng).to be_within(0.001).of(-87.706)
        expect(permit.segment_to_lat).to be_within(0.001).of(41.885)
        expect(permit.segment_to_lng).to be_within(0.001).of(-87.706)
      end

      it "reports each failure to Sentry" do
        described_class.perform_now(permit.id)

        expect(Sentry).to have_received(:capture_message)
          .with(/Geocode failed/, hash_including(level: :warning)).at_least(:once)
      end
    end

    context "when the permit no longer exists" do
      it "does not raise" do
        expect { described_class.perform_now(-1) }.not_to raise_error
      end
    end

    context "when the permit has no segment addresses" do
      let!(:permit) do
        create(:cdot_permit,
          street_number_from: nil, street_number_to: nil,
          direction: nil, street_name: nil)
      end

      it "does not attempt geocoding" do
        expect(GeocodeAddress).not_to receive(:new)
        described_class.perform_now(permit.id)
      end
    end
  end
end
