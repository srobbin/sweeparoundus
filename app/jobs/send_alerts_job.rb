class SendAlertsJob < ApplicationJob
  def perform
    Sweep.where("date_1 = ?", Date.tomorrow).preload(:confirmed_alerts).each do |sweep|
      sweep.confirmed_alerts.each do |alert|
        AlertMailer.with(alert: alert, sweep: sweep).reminder.deliver_later
      end
    end
  end
end
