class CarryOverExistingAlerts
  MAX_FAILURES = 100

  attr_reader :write, :send_mailers
  attr_accessor :failures

  # CarryOverExistingAlerts.new(write: false).call
  #
  # Pass send_mailers: false to re-link alerts to areas without enqueuing the
  # annual_schedule_live email (e.g. for mid-season schedule corrections).
  def initialize(write: false, send_mailers: true)
    @write = write
    @send_mailers = send_mailers
    @failures = []
  end

  def call
    total_alert_count = Alert.confirmed.with_street_address.count
    updated_count = 0

    Alert.confirmed.with_street_address.each do |alert|
      if !write && failures.length > MAX_FAILURES
        puts "Exceeded #{MAX_FAILURES} failures during test run, stopping early"
        break
      end

      lat, lng = get_address_coords(alert)

      unless lat && lng
        next
      end

      area = find_area(lat, lng)

      if area
        updated_count += 1
        puts "#{updated_count}/#{total_alert_count} alerts updated"
        update_alert(alert, area, lat, lng) if write
      else
        add_to_failures(alert, "area_not_found")
      end
    end

    log_result
  end

  private

  def get_address_coords(alert)
    if alert.lat.present? && alert.lng.present?
      return [ alert.lat, alert.lng ]
    end

    geocode_address(alert)
  end

  def geocode_address(alert)
    geocoder = GeocodeAddress.new(address: alert.street_address)
    result = geocoder.call

    if result
      [ result.lat, result.lng ]
    else
      add_to_failures(alert, geocoder.error_reason || "geocode_failed")
      nil
    end
  end

  def update_alert(alert, area, lat, lng)
    begin
      alert.update!(area: area, lat: lat, lng: lng)
      alert.reload
      AlertMailer.with(alert: alert).annual_schedule_live.deliver_later if send_mailers
    rescue ActiveRecord::RecordInvalid => e
      add_to_failures(alert, "update_failed: #{e.message}")
    end
  end

  def add_to_failures(alert, reason)
    puts "failure: #{reason}"
    failures << { id: alert.id, address: alert.street_address, reason: reason }
  end

  def find_area(lat, lng)
    point = RGeo::Geos.factory(srid: 0).point(lng, lat)
    areas = Area.arel_table
    Area.where(areas[:shape].st_contains(point)).first
  end

  def log_result
    if failures.any?
      unique_failures = failures.uniq
      Sentry.capture_message(
        "[CarryOverExistingAlerts] #{unique_failures.count} alert(s) failed",
        level: :warning,
        contexts: { carry_over: { failure_count: unique_failures.count, sample: unique_failures.first(10) } },
      )
      "ERROR: Failed to find areas for #{unique_failures.count} alert(s): #{unique_failures}"
    else
      "SUCCESS: All alerts have been assigned to an area"
    end
  end
end
