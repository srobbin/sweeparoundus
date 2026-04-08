class CarryOverExistingAlerts
  MAX_FAILURES = 100

  attr_reader :write
  attr_accessor :failures

  # CarryOverExistingAlerts.new(write: false).call
  def initialize(write: false)
    @write = write
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
      return [alert.lat, alert.lng]
    end

    geocode_address(alert)
  end

  def geocode_address(alert)
    address = alert.street_address
    api_key = ENV["GOOGLE_MAPS_BACKEND_API_KEY"]
    escaped_address = CGI.escape(address)
    url = URI("https://maps.googleapis.com/maps/api/geocode/json?address=#{escaped_address}&key=#{api_key}")

    max_retries = 5
    retry_count = 0

    loop do
      begin
        response = make_request(url)
      rescue StandardError => e
        if retry_count < max_retries
          sleep(2**retry_count)
          retry_count += 1
          next
        else
          add_to_failures(alert, "http_error: #{e.message}")
          return
        end
      end

      result = parse_response(response, alert, retry_count, max_retries)
      return result unless result == :retry

      retry_count += 1
      next
    end
  end

  def make_request(url)
    sleep(0.1)
    Net::HTTP.get(url)
  end

  def parse_response(response, alert, retry_count, max_retries)
    json = JSON.parse(response)

    if json["status"] == "OK"
      result = json["results"][0]
      lat = result.dig("geometry", "location", "lat")
      lng = result.dig("geometry", "location", "lng")

      [lat, lng]
    elsif %w[REQUEST_DENIED OVER_QUERY_LIMIT UNKNOWN_ERROR].include?(json["status"]) && retry_count < max_retries
      sleep(2**retry_count)
      :retry
    else
      add_to_failures(alert, "geocode_status: #{json['status']}")
      nil
    end
  end

  def update_alert(alert, area, lat, lng)
    begin
      alert.update!(area: area, lat: lat, lng: lng)
      alert.reload
      AlertMailer.with(alert: alert).annual_schedule_live.deliver_later
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
      "ERROR: Failed to find areas for #{unique_failures.count} alert(s): #{unique_failures}"
    else
      "SUCCESS: All alerts have been assigned to an area"
    end
  end
end
