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

    describe "email domain MX validation" do
      it "is valid when the domain has MX records" do
        alert = Alert.new(email: "user@gmail.com", area: area)

        expect(alert).to be_valid
      end

      it "is valid when the domain has no MX but has A records" do
        dns = instance_double(Resolv::DNS)
        allow(Resolv::DNS).to receive(:open).and_yield(dns)
        allow(dns).to receive(:timeouts=)
        allow(dns).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::MX)
          .and_return([])
        allow(dns).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::A)
          .and_return([ instance_double(Resolv::DNS::Resource::IN::A) ])

        alert = Alert.new(email: "user@example.com", area: area)

        expect(alert).to be_valid
      end

      it "is invalid when the domain has no MX or A records" do
        dns = instance_double(Resolv::DNS)
        allow(Resolv::DNS).to receive(:open).and_yield(dns)
        allow(dns).to receive(:timeouts=)
        allow(dns).to receive(:getresources).and_return([])

        alert = Alert.new(email: "opera1651@gmail.como", area: area)

        expect(alert).not_to be_valid
        expect(alert.errors[:email]).to include("domain does not appear to accept email")
      end

      it "sets a valid positive timeout on the resolver" do
        dns = Resolv::DNS.new
        allow(Resolv::DNS).to receive(:open).and_yield(dns)
        allow(dns).to receive(:getresources).and_return([])

        alert = Alert.new(email: "user@nodns.example", area: area)

        expect { alert.valid? }.not_to raise_error
      end

      it "does not block signups when DNS lookup fails" do
        allow(Resolv::DNS).to receive(:open).and_raise(Resolv::ResolvError)

        alert = Alert.new(email: "user@flaky-dns.com", area: area)

        expect(alert).to be_valid
      end

      it "does not block signups when DNS lookup times out" do
        allow(Resolv::DNS).to receive(:open).and_raise(Resolv::ResolvTimeout)

        alert = Alert.new(email: "user@slow-dns.com", area: area)

        expect(alert).to be_valid
      end

      it "skips MX validation when email format is already invalid" do
        alert = Alert.new(email: "not-an-email", area: area)

        expect(Resolv::DNS).not_to receive(:open)
        alert.valid?
        expect(alert.errors[:email]).to be_present
      end

      it "skips MX validation when phone is present and email is nil" do
        alert = Alert.new(phone: "3125551234", email: nil, area: area)

        expect(Resolv::DNS).not_to receive(:open)
        expect(alert).to be_valid
      end
    end

    describe "email + street_address uniqueness" do
      let!(:existing) do
        create(:alert, :confirmed, email: "dupe@example.com", street_address: "123 Main St", area: area)
      end

      it "is invalid when email and street_address match an existing record" do
        alert = Alert.new(email: "dupe@example.com", street_address: "123 Main St", area: area)

        expect(alert).not_to be_valid
        expect(alert.errors[:email]).to be_present
      end

      it "is valid when same email has a different street_address" do
        alert = Alert.new(email: "dupe@example.com", street_address: "456 Oak Ave", area: area)

        expect(alert).to be_valid
      end

      it "is valid when different email has the same street_address" do
        alert = Alert.new(email: "other@example.com", street_address: "123 Main St", area: area)

        expect(alert).to be_valid
      end

      it "prevents duplicate alerts with the same email, nil street_address, and same area" do
        create(:alert, :confirmed, email: "nil-addr@example.com", street_address: nil, area: area)
        alert = Alert.new(email: "nil-addr@example.com", street_address: nil, area: area)

        expect(alert).not_to be_valid
        expect(alert.errors[:email]).to include("has already been taken")
      end

      it "allows same email with nil street_address across different areas" do
        create(:alert, :confirmed, email: "nil-addr@example.com", street_address: nil, area: area)
        other_area = create(:area, number: 99, ward: 99, slug: "ward-99-sweep-area-99", shortcode: "W99A99")
        alert = Alert.new(email: "nil-addr@example.com", street_address: nil, area: other_area)

        expect(alert).to be_valid
      end

      it "allows a nil street_address subscription alongside a street_address subscription in the same area" do
        create(:alert, :confirmed, email: "both@example.com", street_address: "123 Main St", area: area)
        alert = Alert.new(email: "both@example.com", street_address: nil, area: area)

        expect(alert).to be_valid
      end

      it "confirms a nil street_address alert when the same email has a street_address alert in the area" do
        create(:alert, :confirmed, email: "both@example.com", street_address: "123 Main St", area: area)
        general = create(:alert, :unconfirmed, email: "both@example.com", street_address: nil, area: area)

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
