class RegeocodeAlertJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    Rails.logger.error(
      "[RegeocodeAlertJob] All retries exhausted for alert #{job.arguments.first}: " \
      "#{error.class}: #{error.message}"
    )
    Sentry.capture_exception(error, contexts: {
      regeocode_alert: { alert_id: job.arguments.first }
    })
  end

  def perform(alert_id)
    alert = Alert.find_by(id: alert_id)
    return if alert.nil?

    result = GeocodeAddress.new(address: alert.street_address).call
    unless result
      report_regeocode_failure(alert_id, "geocode_failed", street_address: alert.street_address)
      return
    end

    area = Area.find_by_coordinates(result.lat, result.lng)
    unless area
      report_regeocode_failure(
        alert_id,
        "area_not_found",
        street_address: alert.street_address,
        lat: result.lat,
        lng: result.lng
      )
    end

    attrs = { lat: result.lat, lng: result.lng }
    attrs[:area] = area if area
    alert.update!(attrs)
  end

  private

  def report_regeocode_failure(alert_id, reason, **extra)
    Sentry.capture_message(
      "[RegeocodeAlertJob] #{reason.tr('_', ' ')}",
      level: :warning,
      contexts: { regeocode_alert: { alert_id: alert_id, reason: reason }.merge(extra) }
    )
  end
end
