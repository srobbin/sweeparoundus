require "rails_helper"

RSpec.describe Alert do
  let!(:area) { create(:area) }

  describe "validations" do
    it "is valid with an email and area" do
      alert = build(:alert, area: area)

      expect(alert).to be_valid
    end

    it "is valid with a phone number and no email" do
      alert = Alert.new(phone: "3125551234", area: area)

      expect(alert).to be_valid
    end

    it "is invalid without both email and phone" do
      alert = Alert.new(area: area)

      expect(alert).not_to be_valid
      expect(alert.errors[:base]).to include("You must specify either an email or phone number.")
    end

    it "is invalid with a malformed email" do
      alert = Alert.new(email: "not-an-email", area: area)

      expect(alert).not_to be_valid
      expect(alert.errors[:email]).to be_present
    end

    it "is valid with a properly formatted email" do
      alert = Alert.new(email: "user@example.com", area: area)

      expect(alert).to be_valid
    end

    it "skips email validation when phone is present" do
      alert = Alert.new(phone: "3125551234", email: nil, area: area)

      expect(alert).to be_valid
    end

    it "accepts emails with dots and hyphens" do
      alert = Alert.new(email: "first.last-name@sub.example.com", area: area)

      expect(alert).to be_valid
    end

    it "belongs to area optionally" do
      alert = Alert.new(email: "user@example.com", area: nil)

      expect(alert).to be_valid
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
    end

    describe ".without_coords" do
      it "returns alerts without lat and lng" do
        expect(Alert.without_coords).to include(unconfirmed_without_address)
        expect(Alert.without_coords).not_to include(confirmed_with_address)
      end
    end

    describe ".email" do
      let!(:phone_only_alert) { Alert.create!(phone: "3125551234", area: area) }

      it "returns alerts with an email" do
        expect(Alert.email).to include(confirmed_with_address)
        expect(Alert.email).not_to include(phone_only_alert)
      end
    end

    describe ".phone" do
      let!(:phone_only_alert) { Alert.create!(phone: "3125551234", area: area) }

      it "returns alerts with a phone number" do
        expect(Alert.phone).to include(phone_only_alert)
        expect(Alert.phone).not_to include(confirmed_with_address)
      end
    end
  end
end
