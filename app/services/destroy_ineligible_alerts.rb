# destroys alerts that are ineligible for annual carry-over due to being unconfirmed or sans a street address
class DestroyIneligibleAlerts
  attr_reader :alerts_to_destroy, :alerts_to_notify, :write

  # DestroyIneligibleAlerts.new(write: false).call
  def initialize(write: false)
    @alerts_to_destroy = Alert.without_street_address.or(Alert.unconfirmed)
    @alerts_to_notify = @alerts_to_destroy.confirmed
    @write = write
  end

  def call
    return "TEST: #{alerts_to_destroy.count} alerts (unconfirmed or without street address) marked for deletion" unless write

    begin
      send_mailers_to_confirmed_users
      destroyed_objects = alerts_to_destroy.destroy_all
      "SUCCESS: #{destroyed_objects.count} alerts (unconfirmed or without street address) deleted"
    rescue => e
      "ERROR: Failed to delete alerts - #{e.message}"
    end
  end

  private

  def send_mailers_to_confirmed_users
    alerts_to_notify.each do |alert|
      AlertMailer.with(alert: alert).deleted_notification.deliver_later
    end
  end
end
