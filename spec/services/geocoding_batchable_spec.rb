# frozen_string_literal: true

require "rails_helper"

RSpec.describe GeocodingBatchable do
  # The module's methods are private; expose them on a throwaway host class so
  # we can exercise the batching logic in isolation.
  let(:host_class) do
    Class.new do
      include GeocodingBatchable
      public :geocoding_batches, :geocoding_batch_key
    end
  end
  let(:host) { host_class.new }

  def permit(overrides = {})
    build(:cdot_permit, overrides)
  end

  describe "#geocoding_batches" do
    it "groups permits that share the same segment addresses into one batch" do
      permits = [ permit, permit ]

      batches = host.geocoding_batches(permits)

      expect(batches.size).to eq(1)
      expect(batches.first).to match_array(permits)
    end

    it "treats addresses that normalize equal as the same batch" do
      a = permit(direction: "N", street_name: "CALIFORNIA", suffix: "AVE")
      b = permit(direction: "n", street_name: "  california ", suffix: "ave")

      batches = host.geocoding_batches([ a, b ])

      expect(batches.size).to eq(1)
      expect(batches.first).to match_array([ a, b ])
    end

    it "puts permits with different segment addresses into separate batches" do
      california = permit(street_name: "CALIFORNIA")
      kedzie = permit(street_name: "KEDZIE")

      batches = host.geocoding_batches([ california, kedzie ])

      expect(batches.size).to eq(2)
      expect(batches.map(&:first)).to match_array([ california, kedzie ])
    end

    it "splits a large same-address group into slices of GEOCODE_JOB_BATCH_SIZE" do
      size = GeocodingBatchable::GEOCODE_JOB_BATCH_SIZE
      permits = Array.new(size + 1) { permit }

      batches = host.geocoding_batches(permits)

      expect(batches.map(&:size)).to eq([ size, 1 ])
    end

    it "ignores blank address endpoints when keying batches" do
      both = permit(street_number_from: 3300, street_number_to: 3350)
      from_only = permit(street_number_from: 3300, street_number_to: nil)

      batches = host.geocoding_batches([ both, from_only ])

      expect(batches.size).to eq(2)
    end

    it "returns an empty array for no permits" do
      expect(host.geocoding_batches([])).to eq([])
    end
  end
end
