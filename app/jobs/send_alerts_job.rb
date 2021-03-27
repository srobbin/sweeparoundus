class SendAlertsJob < ApplicationJob
  def perform
    Sweep.where("date_1 = ?", Date.tomorrow).each do |sweep|
      sweep.alerts.confirmed.each do |alert|
        if alert.email.present?
          AlertMailer.with(alert: alert, sweep: sweep).reminder.deliver_later
        elsif alert.phone.present?
          area = alert.area
          SendSmsJob.perform_later(
            to: alert.phone,
            message: "Street sweeping for #{area.name} will begin tommorrow. To unsubscribe, text STOP #{area.shortcode}. #{area_url(area)}"
          )
        end
      end
    end
  end
end
