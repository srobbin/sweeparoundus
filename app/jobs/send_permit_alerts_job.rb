class SendPermitAlertsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |_job, error|
    Rails.logger.error("[SendPermitAlertsJob] All retries exhausted: #{error.class}: #{error.message}")
    Sentry.capture_exception(error)
  end

  TIME_ZONE = "America/Chicago".freeze

  def perform
    permits = upcoming_permits.to_a
    pre_filter_skipped = 0
    permits_with_alerts = 0
    matches_by_alert_id = {}
    alert_ids_by_permit = {}

    Sentry.set_context("job_params", {
      permits_in_scope: permits.size,
      permit_keys: permits.map(&:unique_key)
    })

    permits.each do |permit|
      alert_ids_by_permit[permit.id] = []

      service = FindCdotPermitAffectedAlerts.new(permit: permit)
      affected = service.call
      pre_filter_skipped += 1 if service.pre_filter_skipped?
      next if affected.empty?

      notifiable_alerts = affected.select { |affected_alert| notifiable?(affected_alert.alert) }
      next if notifiable_alerts.empty?

      permits_with_alerts += 1
      notifiable_alerts.each do |affected_alert|
        alert_ids_by_permit[permit.id] << affected_alert.alert.id
        bucket = matches_by_alert_id[affected_alert.alert.id] ||= { alert: affected_alert.alert, matches: [] }
        bucket[:matches] << {
          permit: permit,
          distance_feet: affected_alert.distance_feet,
          line_from: service.line_from,
          line_to: service.line_to
        }
      end

      Rails.logger.info(
        "[SendPermitAlertsJob] permit=#{permit.unique_key} " \
        "segment=#{permit.segment_label.inspect} " \
        "matched=#{affected.size} notified=#{notifiable_alerts.size}"
      )
      Sentry.logger.info(
        "send_permit_alerts.permit_matched permit_key=%{permit_key} matched=%{matched} notified=%{notified}",
        permit_key: permit.unique_key, matched: affected.size, notified: notifiable_alerts.size,
      )
    end

    enqueued_count = 0

    # Stamps and mailer enqueues share a transaction so a failure in either
    # rolls back both — preventing permits from being marked "sent" without
    # emails actually being enqueued. Rails 7.2 defers the Redis push until
    # after commit (enqueue_after_transaction_commit: :always).
    ActiveRecord::Base.transaction do
      mark_permits_notified(permits, alert_ids_by_permit)

      matches_by_alert_id.each_value do |bucket|
        PermitMailer.with(alert: bucket[:alert], matches: bucket[:matches]).notify.deliver_later
        enqueued_count += 1
      end
    end

    summary = {
      permits_scanned: permits.size,
      pre_filter_skipped: pre_filter_skipped,
      permits_with_alerts: permits_with_alerts,
      emails_enqueued: enqueued_count,
      alert_ids_notified: matches_by_alert_id.keys
    }

    Sentry.set_context("job_result", summary)

    if enqueued_count.zero? && permits_with_alerts.positive?
      Sentry.capture_message(
        "[SendPermitAlertsJob] Had notifiable matches but enqueued 0 emails",
        level: :error,
        contexts: { job_result: summary },
      )
    end

    Rails.logger.info(
      "[SendPermitAlertsJob] SUCCESS: scanned #{permits.size} permit(s), " \
      "#{pre_filter_skipped} pre-filtered, " \
      "#{permits_with_alerts} had notifiable alerts, " \
      "#{enqueued_count} email(s) enqueued"
    )
    Sentry.logger.info(
      "send_permit_alerts.completed permits_scanned=%{permits_scanned} pre_filter_skipped=%{pre_filter_skipped} permits_with_alerts=%{permits_with_alerts} emails_enqueued=%{emails_enqueued}",
      permits_scanned: permits.size, pre_filter_skipped: pre_filter_skipped,
      permits_with_alerts: permits_with_alerts, emails_enqueued: enqueued_count,
    )
  end

  private

  def mark_permits_notified(permits, alert_ids_by_permit)
    now = Time.current

    with_alerts, without_alerts = permits.partition do |permit|
      alert_ids_by_permit.fetch(permit.id, []).any?
    end

    if without_alerts.any?
      CdotPermit.where(id: without_alerts.map(&:id))
                .update_all(processed_alert_ids: [], notifications_sent_at: now, updated_at: now)
    end

    if with_alerts.any?
      rows = with_alerts.map do |permit|
        ids = alert_ids_by_permit.fetch(permit.id).uniq
        { id: permit.id, unique_key: permit.unique_key, processed_alert_ids: ids, notifications_sent_at: now }
      end

      CdotPermit.upsert_all(rows, unique_by: :id, update_only: %i[processed_alert_ids notifications_sent_at])
    end
  end

  # The proximity query already filters on confirmed/address/coords/
  # permit_notifications; we just guard against blank email (phone-only alerts).
  def notifiable?(alert)
    alert.email.present?
  end

  def upcoming_permits
    now = Time.current.in_time_zone(TIME_ZONE)
    start_of_today = now.beginning_of_day
    start_of_tomorrow = start_of_today + 1.day
    end_of_tomorrow = start_of_tomorrow + 1.day

    CdotPermit
      .with_open_status
      .where(notifications_sent_at: nil)
      .where(
        "(application_start_date >= :tomorrow AND application_start_date < :day_after) " \
        "OR (application_start_date >= :today AND application_start_date < :tomorrow " \
            "AND created_at >= :today)",
        today: start_of_today, tomorrow: start_of_tomorrow, day_after: end_of_tomorrow
      )
  end
end
