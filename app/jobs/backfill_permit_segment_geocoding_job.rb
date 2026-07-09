class BackfillPermitSegmentGeocodingJob < ApplicationJob
  include GeocodingBatchable

  queue_as :default

  def perform
    permits = CdotPermit.where(segment_from_lat: nil)
    count = 0

    permits.find_in_batches do |permit_batch|
      geocoding_batches(permit_batch).each do |batch|
        GeocodePermitSegmentJob.set(wait: count * GEOCODE_JOB_STAGGER).perform_later(batch.map(&:id))
        count += 1
      end
    end

    Rails.logger.info("[BackfillPermitSegmentGeocodingJob] Enqueued #{count} geocoding batch(es)")
  rescue StandardError => e
    Rails.logger.error("[BackfillPermitSegmentGeocodingJob] #{e.class}: #{e.message}")
    Sentry.capture_exception(e, contexts: {
      backfill_permit_segment_geocoding: { enqueued_before_failure: count }
    })
    raise
  end
end
