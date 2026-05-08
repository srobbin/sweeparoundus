class ReverseGeocodeAddress < GoogleGeocoder
  def initialize(lat:, lng:)
    @lat = Float(lat)
    @lng = Float(lng)
  end

  private

  def query_params
    { latlng: "#{@lat},#{@lng}" }
  end

  def cache_key
    "reverse_geocode:#{@lat.round(5)},#{@lng.round(5)}"
  end

  def log_identifier
    "#{@lat},#{@lng}"
  end

  def parse_success(json)
    address = json.dig("results", 0, "formatted_address")
    address&.sub(/, USA\z/, "")
  end
end
