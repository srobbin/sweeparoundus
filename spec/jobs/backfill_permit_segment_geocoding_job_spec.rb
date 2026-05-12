# frozen_string_literal: true

require "rails_helper"

RSpec.describe BackfillPermitSegmentGeocodingJob, type: :job do
  before do
    allow(GeocodePermitSegmentJob).to receive(:set).and_return(GeocodePermitSegmentJob)
    allow(GeocodePermitSegmentJob).to receive(:perform_later)
  end

  describe "#perform" do
    it "enqueues geocoding for permits missing segment coordinates" do
      missing = create(:cdot_permit, segment_from_lat: nil, segment_from_lng: nil)

      described_class.perform_now

      expect(GeocodePermitSegmentJob).to have_received(:perform_later).with(missing.id)
    end

    it "skips permits that are already geocoded" do
      create(:cdot_permit,
        segment_from_lat: 41.94, segment_from_lng: -87.70,
        segment_to_lat: 41.95, segment_to_lng: -87.70)

      described_class.perform_now

      expect(GeocodePermitSegmentJob).not_to have_received(:perform_later)
    end

    it "handles a mix of geocoded and un-geocoded permits" do
      missing1 = create(:cdot_permit, segment_from_lat: nil)
      missing2 = create(:cdot_permit, segment_from_lat: nil)
      create(:cdot_permit,
        segment_from_lat: 41.94, segment_from_lng: -87.70,
        segment_to_lat: 41.95, segment_to_lng: -87.70)

      described_class.perform_now

      expect(GeocodePermitSegmentJob).to have_received(:perform_later).with(missing1.id)
      expect(GeocodePermitSegmentJob).to have_received(:perform_later).with(missing2.id)
      expect(GeocodePermitSegmentJob).to have_received(:perform_later).twice
    end

    it "does nothing when all permits are geocoded" do
      create(:cdot_permit,
        segment_from_lat: 41.94, segment_from_lng: -87.70,
        segment_to_lat: 41.95, segment_to_lng: -87.70)

      described_class.perform_now

      expect(GeocodePermitSegmentJob).not_to have_received(:perform_later)
    end

    it "does nothing when there are no permits" do
      described_class.perform_now

      expect(GeocodePermitSegmentJob).not_to have_received(:perform_later)
    end
  end
end
