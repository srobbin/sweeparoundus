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
          result = case GeocodeAddress.normalize_address(address)
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

      it "reuses geocode results for repeated normalized endpoints in a batch" do
        duplicate = create(:cdot_permit,
          street_number_from: 3300, street_number_to: 3350,
          direction: "n", street_name: "  california ", suffix: "ave")

        described_class.perform_now([ permit.id, duplicate.id ])

        expect(GeocodeAddress).to have_received(:new).twice

        duplicate.reload
        expect(duplicate.segment_from_lat).to be_within(0.0001).of(41.94142)
        expect(duplicate.segment_to_lat).to be_within(0.0001).of(41.94284)
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

    context "when one permit in a batch fails" do
      let!(:other) do
        create(:cdot_permit,
          street_number_from: 100, street_number_to: 150,
          direction: "S", street_name: "KEDZIE", suffix: "AVE")
      end

      before do
        allow(Sentry).to receive(:capture_exception)
        allow(GeocodeAddress).to receive(:new) do |address:|
          raise StandardError, "boom" if address.include?("CALIFORNIA")
          instance_double(GeocodeAddress, call: endpoint_a, error_reason: nil)
        end
      end

      it "isolates the failure and still geocodes the rest of the batch" do
        expect { described_class.perform_now([ permit.id, other.id ]) }.not_to raise_error

        other.reload
        expect(other.segment_from_lat).to be_within(0.0001).of(41.94142)

        permit.reload
        expect(permit.segment_from_lat).to be_nil
      end

      it "reports the failed permit to Sentry" do
        described_class.perform_now([ permit.id, other.id ])

        expect(Sentry).to have_received(:capture_exception)
          .with(instance_of(StandardError), hash_including(:contexts))
      end
    end

    context "when the permit no longer exists" do
      it "does not raise for a valid but absent id" do
        expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
      end
    end

    context "when given a malformed id" do
      it "drops it without attempting to geocode or raising" do
        expect(GeocodeAddress).not_to receive(:new)
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
