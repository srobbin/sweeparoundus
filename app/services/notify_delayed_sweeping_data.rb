# NotifyDelayedSweepingData.new(write: false).call
class NotifyDelayedSweepingData
  attr_reader :write

  def initialize(write: false)
    @write = write
  end

  def call
    raise "SITE_NAME and SITE_URL must be set" if ENV["SITE_NAME"].blank? || ENV["SITE_URL"].blank?

    alerts = Alert.confirmed.email

    return "TEST: #{alerts.count} confirmed alert(s) would be notified" unless write

    notified = 0
    alerts.each do |alert|
      AlertMailer.with(alert: alert).sweeping_data_delayed.deliver_later
      notified += 1
    end

    "SUCCESS: #{notified} confirmed alert(s) notified"
  end
end
