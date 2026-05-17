class BackfillPermitSegmentGeocodingJob < ApplicationJob
  queue_as :default

  GEOCODE_JOB_STAGGER = 0.3.seconds

  def perform
    permits = CdotPermit.where(segment_from_lat: nil)
    count = 0

    permits.find_each do |permit|
      GeocodePermitSegmentJob.set(wait: count * GEOCODE_JOB_STAGGER).perform_later(permit.id)
      count += 1
    end

    Rails.logger.info("[BackfillPermitSegmentGeocodingJob] Enqueued #{count} permit(s) for geocoding")
  rescue StandardError => e
    Rails.logger.error("[BackfillPermitSegmentGeocodingJob] #{e.class}: #{e.message}")
    Sentry.capture_exception(e, contexts: {
      backfill_permit_segment_geocoding: { enqueued_before_failure: count }
    })
    raise
  end
end
