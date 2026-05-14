class GeocodePermitSegmentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    Rails.logger.error(
      "[GeocodePermitSegmentJob] All retries exhausted for permit #{job.arguments.first}: " \
      "#{error.class}: #{error.message}"
    )
    Sentry.capture_exception(error, contexts: {
      geocode_permit_segment: { cdot_permit_id: job.arguments.first },
    })
  end

  def perform(permit_id)
    permit = CdotPermit.find_by(id: permit_id)
    return if permit.nil?

    geocode_segment(permit)
  end

  private

  GEOCODE_THROTTLE_DELAY = 0.15

  def geocode_segment(permit)
    addresses = permit.segment_addresses
    return if addresses.compact.empty?

    from_result = geocode_address(addresses[0])
    sleep(GEOCODE_THROTTLE_DELAY) if addresses[1].present?
    to_result = geocode_address(addresses[1])

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

  def geocode_address(address)
    return nil if address.nil?

    service = GeocodeAddress.new(address: address)
    result = service.call

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
