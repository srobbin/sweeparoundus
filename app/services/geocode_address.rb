class GeocodeAddress < GoogleGeocoder
  Result = Struct.new(:lat, :lng, keyword_init: true)

  def initialize(address:)
    @address = address.to_s.strip
  end

  private

  def blank_query?
    @address.blank?
  end

  def query_params
    { address: @address }
  end

  def cache_key
    "geocode_address:#{@address.downcase}"
  end

  def log_identifier
    @address.inspect
  end

  def parse_success(json)
    lat = json.dig("results", 0, "geometry", "location", "lat")
    lng = json.dig("results", 0, "geometry", "location", "lng")
    return nil unless lat && lng

    Result.new(lat: Float(lat), lng: Float(lng))
  end
end
