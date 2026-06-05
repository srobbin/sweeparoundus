require "rails_helper"

RSpec.describe Alert do
  let!(:area) { create(:area) }

  describe "validations" do
    it "is valid with a subscriber and area" do
      alert = build(:alert, area: area)

      expect(alert).to be_valid
    end

    it "is invalid without a subscriber" do
      alert = Alert.new(area: area, subscriber: nil)

      expect(alert).not_to be_valid
      expect(alert.errors[:subscriber]).to be_present
    end

    it "belongs to area optionally" do
      alert = build(:alert, area: nil)

      expect(alert).to be_valid
    end

    it "delegates email to its subscriber" do
      subscriber = create(:subscriber, email: "delegated@example.com")
      alert = build(:alert, subscriber: subscriber, area: area)

      expect(alert.email).to eq("delegated@example.com")
    end

    describe "subscriber-scoped uniqueness" do
      let!(:subscriber) { create(:subscriber, email: "dupe@example.com") }
      let(:other_subscriber) { create(:subscriber, email: "other@example.com") }
      let!(:existing) do
        create(:alert, :confirmed, subscriber: subscriber, street_address: "123 Main St", area: area)
      end

      it "is invalid when street_address matches an existing record for the same subscriber" do
        alert = Alert.new(subscriber: subscriber, street_address: "123 Main St", area: area)

        expect(alert).not_to be_valid
        expect(alert.errors[:street_address]).to be_present
      end

      it "is valid when the same subscriber has a different street_address" do
        alert = Alert.new(subscriber: subscriber, street_address: "456 Oak Ave", area: area)

        expect(alert).to be_valid
      end

      it "is valid when a different subscriber has the same street_address" do
        alert = Alert.new(subscriber: other_subscriber, street_address: "123 Main St", area: area)

        expect(alert).to be_valid
      end

      it "prevents duplicate alerts with the same subscriber, nil street_address, and same area" do
        create(:alert, :confirmed, subscriber: other_subscriber, street_address: nil, area: area)
        alert = Alert.new(subscriber: other_subscriber, street_address: nil, area: area)

        expect(alert).not_to be_valid
        expect(alert.errors[:area_id]).to include("has already been taken")
      end

      it "allows same subscriber with nil street_address across different areas" do
        create(:alert, :confirmed, subscriber: other_subscriber, street_address: nil, area: area)
        other_area = create(:area, number: 99, ward: 99, slug: "ward-99-sweep-area-99", shortcode: "W99A99")
        alert = Alert.new(subscriber: other_subscriber, street_address: nil, area: other_area)

        expect(alert).to be_valid
      end

      it "allows a nil street_address subscription alongside a street_address subscription in the same area" do
        alert = Alert.new(subscriber: subscriber, street_address: nil, area: area)

        expect(alert).to be_valid
      end

      it "confirms a nil street_address alert when the same subscriber has a street_address alert in the area" do
        general = create(:alert, :unconfirmed, subscriber: subscriber, street_address: nil, area: area)

        expect(general.update(confirmed: true)).to be(true)
      end
    end
  end

  describe "scopes" do
    let!(:confirmed_with_address) do
      create(:alert, :confirmed, :with_address, area: area, lat: 41.885, lng: -87.712)
    end
    let!(:unconfirmed_without_address) do
      create(:alert, :unconfirmed, area: area)
    end

    describe ".confirmed" do
      it "returns only confirmed alerts" do
        expect(Alert.confirmed).to include(confirmed_with_address)
        expect(Alert.confirmed).not_to include(unconfirmed_without_address)
      end
    end

    describe ".unconfirmed" do
      it "returns only unconfirmed alerts" do
        expect(Alert.unconfirmed).to include(unconfirmed_without_address)
        expect(Alert.unconfirmed).not_to include(confirmed_with_address)
      end
    end

    describe ".with_street_address" do
      it "returns alerts that have a street address" do
        expect(Alert.with_street_address).to include(confirmed_with_address)
        expect(Alert.with_street_address).not_to include(unconfirmed_without_address)
      end
    end

    describe ".without_street_address" do
      it "returns alerts without a street address" do
        expect(Alert.without_street_address).to include(unconfirmed_without_address)
        expect(Alert.without_street_address).not_to include(confirmed_with_address)
      end
    end

    describe ".with_coords" do
      it "returns alerts that have lat and lng" do
        expect(Alert.with_coords).to include(confirmed_with_address)
        expect(Alert.with_coords).not_to include(unconfirmed_without_address)
      end

      it "excludes alerts with only one of lat or lng set" do
        lat_only = create(:alert, :confirmed, area: area, lat: 41.885, lng: nil)
        lng_only = create(:alert, :confirmed, area: area, lat: nil, lng: -87.712)

        expect(Alert.with_coords).not_to include(lat_only)
        expect(Alert.with_coords).not_to include(lng_only)
      end
    end

    describe ".without_coords" do
      it "returns alerts without lat and lng" do
        expect(Alert.without_coords).to include(unconfirmed_without_address)
        expect(Alert.without_coords).not_to include(confirmed_with_address)
      end
    end

    describe ".with_location" do
      it "returns alerts that have a PostGIS location" do
        expect(Alert.with_location).to include(confirmed_with_address)
        expect(Alert.with_location).not_to include(unconfirmed_without_address)
      end
    end

    describe ".permit_notifications_enabled" do
      let!(:opted_in) do
        create(:alert, :confirmed, area: area, permit_notifications: true)
      end
      let!(:opted_out) do
        create(:alert, :confirmed, area: area, permit_notifications: false)
      end

      it "returns only alerts with permit_notifications enabled" do
        expect(Alert.permit_notifications_enabled).to include(opted_in)
        expect(Alert.permit_notifications_enabled).not_to include(opted_out)
      end
    end
  end

  describe "#update_location_from_coords" do
    it "populates location from lat and lng on create" do
      alert = create(:alert, :confirmed, area: area, lat: 41.885, lng: -87.712)

      expect(alert.location).to be_present
      expect(alert.location.latitude).to be_within(0.001).of(41.885)
      expect(alert.location.longitude).to be_within(0.001).of(-87.712)
    end

    it "updates location when lat or lng changes" do
      alert = create(:alert, :confirmed, area: area, lat: 41.885, lng: -87.712)

      alert.update!(lat: 41.920, lng: -87.650)

      expect(alert.location.latitude).to be_within(0.001).of(41.920)
      expect(alert.location.longitude).to be_within(0.001).of(-87.650)
    end

    it "clears location when lat is set to nil" do
      alert = create(:alert, :confirmed, area: area, lat: 41.885, lng: -87.712)
      expect(alert.location).to be_present

      alert.update!(lat: nil, lng: nil)

      expect(alert.reload.location).to be_nil
    end

    it "does not touch location when unrelated attributes change" do
      alert = create(:alert, :confirmed, area: area, lat: 41.885, lng: -87.712)
      original_location = alert.location

      alert.update!(street_address: "999 New St")

      expect(alert.reload.location).to eq(original_location)
    end
  end
end
