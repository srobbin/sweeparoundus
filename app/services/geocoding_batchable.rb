# Groups permits into batches that can each be handed to a single
# GeocodePermitSegmentJob. Permits sharing the same set of (normalized) segment
# addresses are grouped together so the job's in-memory result cache collapses
# them into at most two Google Geocoding API calls per batch.
module GeocodingBatchable
  # Spacing between enqueued jobs so we don't burst the geocoding API.
  GEOCODE_JOB_STAGGER = 0.3.seconds
  # Upper bound on permits per job to keep any single job's runtime bounded.
  GEOCODE_JOB_BATCH_SIZE = 50

  private

  def geocoding_batches(permits)
    permits
      .group_by { |permit| geocoding_batch_key(permit) }
      .values
      .flat_map { |group| group.each_slice(GEOCODE_JOB_BATCH_SIZE).to_a }
  end

  def geocoding_batch_key(permit)
    permit.segment_addresses.map { |address| GeocodeAddress.normalize_address(address) }.compact_blank.sort
  end
end
