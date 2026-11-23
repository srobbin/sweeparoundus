# NotifyExtendedSeason.new(write: false).call
# One-off 2026 late-season notice: City extended posted sweeping through Dec 17,
# but DSS will not update the open-data schedule, so site alerts will miss extras.
# Run only one instance at a time. Progress is saved after each enqueue; a crash
# between the queue write and database update can still duplicate that notice.
class NotifyExtendedSeason
  CAMPAIGN = "extended_season_2026"

  attr_reader :write, :year

  def initialize(write: false, year: Time.current.year.to_s)
    @write = write
    @year = year
  end

  def call
    raise "SITE_NAME and SITE_URL must be set" if ENV["SITE_NAME"].blank? || ENV["SITE_URL"].blank?

    queued_alert_ids = OneOffNotification.where(campaign: CAMPAIGN).select(:alert_id)
    alerts = Alert.confirmed.joins(:area).includes(:area).where.not(id: queued_alert_ids)

    return "TEST: #{alerts.count} confirmed alert(s) would be notified of extended season" unless write

    lookup = WardOfficeLookup.new(year: year)
    notified = 0
    alerts.find_each do |alert|
      ward_office = begin
        lookup.for_ward(alert.area.ward) if lookup && alert.area
      rescue SystemCallError, CSV::MalformedCSVError => e
        Rails.logger.warn("[NotifyExtendedSeason] Ward office lookup failed: #{e.class}: #{e.message}")
        lookup = nil
      end
      job = AlertMailer.with(alert: alert, ward_office: ward_office).extended_season_notice.deliver_later
      raise "Extended season notice enqueue failed for alert #{alert.id}" unless job

      OneOffNotification.create!(campaign: CAMPAIGN, alert: alert, queued_at: Time.current)
      notified += 1
    end

    "SUCCESS: #{notified} confirmed alert(s) notified of extended season"
  end
end
