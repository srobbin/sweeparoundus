require "rails_helper"

RSpec.describe RegeocodeAlertJob, type: :job do
  let!(:area) { create(:area) }
  let!(:alert) do
    create(:alert, :confirmed, :with_address, email: "test@example.com",
           area: area, lat: 41.955, lng: -87.693)
  end

  let(:geocoded_lat) { 41.920 }
  let(:geocoded_lng) { -87.692 }

  describe "#perform" do
    context "when geocoding succeeds and the area lookup returns a result" do
      before do
        allow(GeocodeAddress).to receive(:new).with(address: alert.street_address).and_return(
          instance_double(GeocodeAddress,
                          call: GeocodeAddress::Result.new(lat: geocoded_lat, lng: geocoded_lng))
        )
        allow(Area).to receive(:find_by_coordinates).with(geocoded_lat, geocoded_lng).and_return(area)
      end

      it "updates the alert with geocoded coordinates" do
        described_class.perform_now(alert.id)

        alert.reload
        expect(alert.lat.to_f).to be_within(0.0001).of(geocoded_lat)
        expect(alert.lng.to_f).to be_within(0.0001).of(geocoded_lng)
        expect(alert.area).to eq(area)
      end
    end

    context "when geocoding succeeds but finds no area" do
      before do
        allow(GeocodeAddress).to receive(:new).with(address: alert.street_address).and_return(
          instance_double(GeocodeAddress,
                          call: GeocodeAddress::Result.new(lat: geocoded_lat, lng: geocoded_lng))
        )
        allow(Area).to receive(:find_by_coordinates).with(geocoded_lat, geocoded_lng).and_return(nil)
      end

      it "updates coordinates but keeps the original area" do
        original_area = alert.area

        described_class.perform_now(alert.id)

        alert.reload
        expect(alert.lat.to_f).to be_within(0.0001).of(geocoded_lat)
        expect(alert.lng.to_f).to be_within(0.0001).of(geocoded_lng)
        expect(alert.area).to eq(original_area)
      end
    end

    context "when geocoding returns nil" do
      before do
        allow(GeocodeAddress).to receive(:new).with(address: alert.street_address).and_return(
          instance_double(GeocodeAddress, call: nil)
        )
      end

      it "keeps the original coordinates" do
        original_lat = alert.lat
        original_lng = alert.lng

        described_class.perform_now(alert.id)

        alert.reload
        expect(alert.lat).to eq(original_lat)
        expect(alert.lng).to eq(original_lng)
      end
    end

    context "when the alert no longer exists" do
      it "does not raise" do
        expect {
          described_class.perform_now(SecureRandom.uuid)
        }.not_to raise_error
      end
    end
  end
end
