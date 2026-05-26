class SendAlertsJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |_job, error|
    Rails.logger.error("[SendAlertsJob] All retries exhausted: #{error.class}: #{error.message}")
    Sentry.capture_exception(error)
  end

  def perform
    Sweep.where("date_1 = ?", Date.tomorrow).preload(:confirmed_alerts).each do |sweep|
      sweep.confirmed_alerts.each do |alert|
        AlertMailer.with(alert: alert, sweep: sweep).reminder.deliver_later
      end
    end
  end
end
