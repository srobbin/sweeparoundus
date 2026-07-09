class GeocodePermitSegmentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    permit_ids = Array(job.arguments.first)
    Rails.logger.error(
      "[GeocodePermitSegmentJob] All retries exhausted for permits #{permit_ids.inspect}: " \
      "#{error.class}: #{error.message}"
    )
    Sentry.capture_exception(error, contexts: {
      geocode_permit_segment: { cdot_permit_ids: permit_ids }
    })
  end

  # Accepts one id or a batch of ids. Callers (SyncCdotPermits,
  # BackfillPermitSegmentGeocodingJob) group permits that share the same segment
  # addresses into a batch, so `geocode_cache` collapses a batch into at most
  # two geocoding API calls. Because of that grouping there's no inter-permit
  # throttle in this job; the only sleep is between a permit's two endpoints.
  def perform(permit_ids)
    permit_ids = sanitize_permit_ids(permit_ids)
    permits_by_id = CdotPermit.where(id: permit_ids).index_by(&:id)
    geocode_cache = {}

    permit_ids.each do |permit_id|
      permit = permits_by_id[permit_id]
      next unless permit

      # Isolate per-permit failures (e.g. a bad address that fails update!) so one
      # permit can't strand the rest of the batch. Transient/setup errors raised
      # outside this loop still bubble up to retry_on.
      begin
        geocode_segment(permit, geocode_cache)
      rescue StandardError => e
        Rails.logger.error(
          "[GeocodePermitSegmentJob] Failed to geocode permit #{permit_id}: #{e.class}: #{e.message}"
        )
        Sentry.capture_exception(e, contexts: {
          geocode_permit_segment: { cdot_permit_id: permit_id }
        })
      end
    end
  end

  private

  GEOCODE_THROTTLE_DELAY = 0.15
  # CdotPermit#id is a Postgres uuid column, so `where(id: ...)` raises
  # ActiveRecord::StatementInvalid on a malformed value. We filter ids to this
  # shape before querying so a stray argument can't blow up the whole batch.
  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def sanitize_permit_ids(permit_ids)
    candidates = [ permit_ids ].flatten.compact.map(&:to_s)
    valid, invalid = candidates.partition { |id| id.match?(UUID_FORMAT) }

    if invalid.any?
      Rails.logger.warn(
        "[GeocodePermitSegmentJob] Dropped #{invalid.size} malformed permit id(s): #{invalid.inspect}"
      )
    end

    valid
  end

  def geocode_segment(permit, geocode_cache)
    from_address, to_address = permit.segment_addresses
    return if from_address.nil? && to_address.nil?

    from_key = GeocodeAddress.normalize_address(from_address)
    to_key = GeocodeAddress.normalize_address(to_address)

    from_result = geocode_address(from_address, from_key, geocode_cache)
    # Only pause before an actual API request. When `to` is blank or already
    # cached (the common case within a batch) we skip the throttle entirely.
    sleep(GEOCODE_THROTTLE_DELAY) if to_key.present? && !geocode_cache.key?(to_key)
    to_result = geocode_address(to_address, to_key, geocode_cache)

    fallback = permit_fallback_point(permit)
    from_result ||= fallback
    to_result   ||= fallback
    from_result ||= to_result
    to_result   ||= from_result
    return if from_result.nil?

    permit.update!(
      segment_from_lat: from_result.lat,
      segment_from_lng: from_result.lng,
      segment_to_lat: to_result.lat,
      segment_to_lng: to_result.lng,
    )

    Sentry.logger.info(
      "geocode_permit_segment.completed permit_id=%{permit_id} unique_key=%{unique_key}",
      permit_id: permit.id, unique_key: permit.unique_key,
    )
  end

  def geocode_address(address, normalized_address, geocode_cache)
    return nil if address.nil? || normalized_address.blank?
    return geocode_cache[normalized_address] if geocode_cache.key?(normalized_address)

    service = GeocodeAddress.new(address: address)
    result = service.call
    geocode_cache[normalized_address] = result

    if result.nil? && service.error_reason.present?
      Sentry.capture_message(
        "[GeocodePermitSegmentJob] Geocode failed",
        level: :warning,
        contexts: { geocode: { address: address, reason: service.error_reason } },
      )
      Sentry.logger.warn(
        "geocode_permit_segment.geocode_failed address=%{address} reason=%{reason}",
        address: address, reason: service.error_reason,
      )
    end

    result
  end

  def permit_fallback_point(permit)
    return nil if permit.latitude.blank? || permit.longitude.blank?
    GeocodeAddress::Result.new(lat: permit.latitude, lng: permit.longitude)
  end
end
