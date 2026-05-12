# frozen_string_literal: true

require "rails_helper"

RSpec.describe FindCdotPermitAffectedAlerts, type: :service do
  # Endpoint A (3300 N California) and Endpoint B (3350 N California) sit on
  # the same north-south meridian (lng = -87.69870), forming a vertical line.
  let(:from_lat) { 41.94142 }
  let(:from_lng) { -87.69870 }
  let(:to_lat) { 41.94284 }
  let(:to_lng) { -87.69870 }

  let(:permit) do
    create(:cdot_permit,
      street_number_from: 3300,
      street_number_to: 3350,
      direction: "N",
      street_name: "CALIFORNIA",
      suffix: "AVE",
      latitude: 41.94142,
      longitude: -87.69870,
      segment_from_lat: from_lat,
      segment_from_lng: from_lng,
      segment_to_lat: to_lat,
      segment_to_lng: to_lng)
  end

  let(:area) { create(:area) }

  subject { described_class.new(permit: permit) }

  describe "#call" do
    context "with alerts at varying distances from the construction line" do
      let!(:alert_on_line) do
        create(:alert, :confirmed, :with_address, area: area,
               lat: 41.94200, lng: -87.69870)
      end
      let!(:alert_within_threshold) do
        create(:alert, :confirmed, :with_address, area: area,
               lat: 41.94200, lng: -87.69900)
      end
      let!(:alert_far_away) do
        create(:alert, :confirmed, :with_address, area: area,
               lat: 41.94200, lng: -87.70128)
      end

      it "returns alerts within PROXIMITY_THRESHOLD_FEET of the line" do
        results = subject.call
        alert_ids = results.map { |r| r.alert.id }

        expect(alert_ids).to include(alert_on_line.id, alert_within_threshold.id)
        expect(alert_ids).not_to include(alert_far_away.id)
      end

      it "returns AffectedAlert structs with integer distances in feet" do
        results = subject.call
        on_line = results.find { |r| r.alert.id == alert_on_line.id }

        expect(on_line.distance_feet).to be_a(Integer)
        expect(on_line.distance_feet).to be < 5
      end

      it "orders results by distance ascending" do
        results = subject.call
        expect(results.map(&:distance_feet)).to eq(results.map(&:distance_feet).sort)
      end
    end

    context "alert filtering" do
      let!(:alert_unconfirmed) do
        create(:alert, :unconfirmed, :with_address, area: area,
               lat: 41.94200, lng: -87.69870)
      end
      let!(:alert_no_address) do
        create(:alert, :confirmed, area: area,
               lat: 41.94200, lng: -87.69870)
      end
      let!(:alert_no_coords) do
        create(:alert, :confirmed, :with_address, area: area, lat: nil, lng: nil)
      end
      let!(:alert_opted_out) do
        create(:alert, :confirmed, :with_address, area: area,
               lat: 41.94200, lng: -87.69870, permit_notifications: false)
      end
      let!(:alert_eligible) do
        create(:alert, :confirmed, :with_address, area: area,
               lat: 41.94200, lng: -87.69870)
      end

      it "only includes confirmed alerts with address, coords, and permit notifications enabled" do
        results = subject.call
        expect(results.map { |r| r.alert.id }).to contain_exactly(alert_eligible.id)
      end
    end

    context "when both segment endpoints are stored" do
      let!(:nearby_alert) do
        create(:alert, :confirmed, :with_address, area: area,
               lat: 41.94142, lng: -87.69870)
      end

      it "does not call the geocoder" do
        expect(GeocodeAddress).not_to receive(:new)
        subject.call
      end

      it "exposes the stored line endpoints after #call" do
        subject.call

        expect(subject.line_from.lat).to eq(from_lat)
        expect(subject.line_from.lng).to eq(from_lng)
        expect(subject.line_to.lat).to eq(to_lat)
        expect(subject.line_to.lng).to eq(to_lng)
      end
    end

    context "pre-filter" do
      context "when no alerts are within the radius of the permit point" do
        let!(:far_alert) do
          # ~4 miles south of the permit; well outside any plausible radius.
          create(:alert, :confirmed, :with_address, area: area,
                 lat: 41.88500, lng: -87.69870)
        end

        it "returns an empty array" do
          expect(subject.call).to eq([])
        end

        it "marks the service as pre_filter_skipped?" do
          subject.call
          expect(subject.pre_filter_skipped?).to be true
        end

        it "logs the skip with the radius used" do
          allow(Rails.logger).to receive(:info)
          subject.call
          expect(Rails.logger).to have_received(:info).with(/skipped: no candidate alerts/)
        end
      end

      context "when at least one alert is within the radius" do
        let!(:nearby_alert) do
          create(:alert, :confirmed, :with_address, area: area,
                 lat: 41.94142, lng: -87.69870)
        end

        it "does not mark the service as pre_filter_skipped?" do
          subject.call
          expect(subject.pre_filter_skipped?).to be false
        end
      end

      context "when the permit has no lat/lng (no CDOT centroid)" do
        let(:permit) do
          create(:cdot_permit,
            street_number_from: 3300, street_number_to: 3350,
            direction: "N", street_name: "CALIFORNIA", suffix: "AVE",
            latitude: nil, longitude: nil,
            segment_from_lat: from_lat, segment_from_lng: from_lng,
            segment_to_lat: to_lat, segment_to_lng: to_lng)
        end

        let!(:nearby_alert) do
          create(:alert, :confirmed, :with_address, area: area,
                 lat: 41.94142, lng: -87.69870)
        end

        it "falls through to the line query" do
          subject.call

          expect(subject.pre_filter_skipped?).to be false
        end
      end

      context "when the permit's segment spans many blocks" do
        let(:permit) do
          create(:cdot_permit,
            street_number_from: 3300, street_number_to: 3800,
            direction: "N", street_name: "CALIFORNIA", suffix: "AVE",
            latitude: 41.94142, longitude: -87.69870,
            segment_from_lat: from_lat, segment_from_lng: from_lng,
            segment_to_lat: to_lat, segment_to_lng: to_lng)
        end

        let!(:far_but_in_radius_alert) do
          # ~0.011 deg lat ≈ 4000 ft north of the permit point.
          create(:alert, :confirmed, :with_address, area: area,
                 lat: 41.95242, lng: -87.69870)
        end

        it "does not pre-filter the permit out" do
          subject.call
          expect(subject.pre_filter_skipped?).to be false
        end
      end
    end

    context "when only the 'from' endpoint is stored" do
      let(:to_lat) { nil }
      let(:to_lng) { nil }

      let!(:alert_near_from) do
        create(:alert, :confirmed, :with_address, area: area,
               lat: from_lat, lng: from_lng)
      end

      it "falls back to a degenerate point line and still finds nearby alerts" do
        results = subject.call
        expect(results.map { |r| r.alert.id }).to include(alert_near_from.id)
      end
    end

    context "when only the 'to' endpoint is stored" do
      let(:from_lat) { nil }
      let(:from_lng) { nil }

      let!(:alert_near_to) do
        create(:alert, :confirmed, :with_address, area: area,
               lat: to_lat, lng: to_lng)
      end

      it "falls back to a degenerate point line using the stored endpoint" do
        results = subject.call
        expect(results.map { |r| r.alert.id }).to include(alert_near_to.id)
      end
    end

    context "when no segment coordinates are stored" do
      let(:permit) do
        create(:cdot_permit,
          street_number_from: 3300, street_number_to: 3350,
          direction: "N", street_name: "CALIFORNIA", suffix: "AVE",
          latitude: nil, longitude: nil,
          segment_from_lat: nil, segment_from_lng: nil,
          segment_to_lat: nil, segment_to_lng: nil)
      end

      it "returns an empty array and logs a warning" do
        allow(Rails.logger).to receive(:warn)
        expect(subject.call).to eq([])
        expect(Rails.logger).to have_received(:warn).with(/has no pre-geocoded segment coordinates/)
      end
    end

    context "when the permit has no usable street address fields" do
      let(:permit) do
        create(:cdot_permit,
          street_number_from: nil, street_number_to: nil,
          direction: nil, street_name: nil,
          segment_from_lat: nil, segment_from_lng: nil,
          segment_to_lat: nil, segment_to_lng: nil)
      end

      it "returns an empty array and does not call the geocoder" do
        allow(Rails.logger).to receive(:warn)
        expect(subject.call).to eq([])
        expect(GeocodeAddress).not_to receive(:new)
      end
    end
  end
end
