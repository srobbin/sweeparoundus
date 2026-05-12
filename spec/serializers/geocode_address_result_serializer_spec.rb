# frozen_string_literal: true

require "rails_helper"

RSpec.describe GeocodeAddressResultSerializer do
  let(:result) { GeocodeAddress::Result.new(lat: 41.94142, lng: -87.69870) }

  describe "#serialize?" do
    it "claims GeocodeAddress::Result instances" do
      expect(described_class.instance.serialize?(result)).to be true
    end

    it "does not claim look-alike hashes" do
      expect(described_class.instance.serialize?(lat: 1, lng: 2)).to be false
    end

    it "does not claim nil" do
      expect(described_class.instance.serialize?(nil)).to be false
    end
  end

  describe "round-tripping through ActiveJob::Arguments" do
    it "preserves lat and lng across serialize/deserialize" do
      serialized = ActiveJob::Arguments.serialize([result])
      deserialized = ActiveJob::Arguments.deserialize(serialized)

      expect(deserialized.first).to be_a(GeocodeAddress::Result)
      expect(deserialized.first.lat).to eq(41.94142)
      expect(deserialized.first.lng).to eq(-87.69870)
    end

    it "round-trips when passed inside a hash mailer-param" do
      params = { line_from: result, line_to: result }
      serialized = ActiveJob::Arguments.serialize([params])
      deserialized = ActiveJob::Arguments.deserialize(serialized).first

      expect(deserialized[:line_from]).to be_a(GeocodeAddress::Result)
      expect(deserialized[:line_from].lat).to eq(41.94142)
      expect(deserialized[:line_to].lng).to eq(-87.69870)
    end
  end
end
