class CleanupStaleCdotPermits
  EXPIRATION_BUFFER = 1.day
  STALE_SYNC_THRESHOLD = 14.days

  # Deletes only when BOTH: expired (past application_expire_date + buffer)
  # AND not seen in the API for STALE_SYNC_THRESHOLD. Requiring both prevents
  # a sync outage from wiping the table, and an expire date alone from
  # deleting permits the city quietly renewed.
  def call
    expiration_cutoff = EXPIRATION_BUFFER.ago
    sync_cutoff = STALE_SYNC_THRESHOLD.ago

    count = CdotPermit.where(
      "application_expire_date < :expired AND " \
      "(data_synced_at < :stale OR data_synced_at IS NULL)",
      expired: expiration_cutoff, stale: sync_cutoff
    ).delete_all

    Sentry.logger.info(
      "cleanup_stale_permits.completed deleted_count=%{deleted_count}",
      deleted_count: count, expiration_cutoff: expiration_cutoff.iso8601, sync_cutoff: sync_cutoff.iso8601,
    )

    "SUCCESS: deleted #{count} stale permit(s) " \
      "(expired before #{expiration_cutoff.iso8601} AND not synced since #{sync_cutoff.iso8601})"
  rescue => e
    Rails.logger.error("[CleanupStaleCdotPermits] #{e.class}: #{e.message}")
    Sentry.capture_exception(e, contexts: {
      cleanup_stale_cdot_permits: {
        expiration_cutoff: expiration_cutoff.iso8601,
        sync_cutoff: sync_cutoff.iso8601
      }
    })
    raise
  end
end
