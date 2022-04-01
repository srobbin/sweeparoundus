class SendAlertsJob < ApplicationJob
  def perform
    Sweep.where("date_1 = ?", Date.tomorrow).each do |sweep|
      sweep.alerts.confirmed.each do |alert|
        AlertMailer.with(alert: alert, sweep: sweep).reminder.deliver_later
      end
    end
  end
end
