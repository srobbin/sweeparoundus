class CarryOverExistingAlerts
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
      lat, lng = get_address_coords(alert)

      unless lat && lng
        add_to_failures(alert)
        next
      end

      area = find_area(lat, lng)

      if area
        alert.update(area: area, lat: lat, lng: lng) if write
        updated_count += 1
        puts "#{updated_count}/#{total_alert_count} alerts updated"
      else
        add_to_failures(alert)
        puts "failure"
      end
    end

    log_result
  end

  private

  def get_address_coords(alert)
    address = alert.street_address
    api_key = ENV["GOOGLE_API_KEY"]
    escaped_address = CGI.escape(address)
    url = URI("https://maps.googleapis.com/maps/api/geocode/json?address=#{escaped_address}&key=#{api_key}")
  
    max_retries = 5
    retry_count = 2
  
    begin
      response = make_request(url)
    rescue StandardError => e
      if retry_count < max_retries
        # Double the wait time for each retry (simplified exponential backoff)
        wait_time = 2**retry_count
  
        sleep(wait_time)
  
        retry_count += 1
        retry
      else
        add_to_failures(alert)
        return
      end
    end
  
    parse_response(response, alert)
  end
  
  def make_request(url)
    Net::HTTP.get(url)
  end
  
  def parse_response(response, alert)
    json = JSON.parse(response)
  
    if json["status"] == "OK"
      result = json["results"][0]
      lat = result.dig("geometry", "location", "lat")
      lng = result.dig("geometry", "location", "lng")
  
      [lat, lng]
    else
      add_to_failures(alert)
    end
  end

  def add_to_failures(alert)
    failures << { id: alert.id, address: alert.street_address }
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
