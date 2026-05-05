require "net/http"

class ReverseGeocodeAddress
  CACHE_TTL = 30.days
  NIL_CACHE_TTL = 1.day
  ERROR_CACHE_TTL = 1.hour
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 2

  def initialize(lat:, lng:)
    @lat = Float(lat)
    @lng = Float(lng)
  end

  def call
    cached = Rails.cache.read(cache_key)
    return cached[:address] if cached

    address, transient = fetch_address
    ttl = address ? CACHE_TTL : (transient ? ERROR_CACHE_TTL : NIL_CACHE_TTL)
    Rails.cache.write(cache_key, { address: address }, expires_in: ttl)
    address
  end

  private

  def cache_key
    "reverse_geocode:#{@lat.round(5)},#{@lng.round(5)}"
  end

  def fetch_address
    api_key = ENV["GOOGLE_MAPS_BACKEND_API_KEY"]
    return [nil, false] if api_key.blank?

    uri = URI("https://maps.googleapis.com/maps/api/geocode/json")
    uri.query = URI.encode_www_form(latlng: "#{@lat},#{@lng}", key: api_key)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.get(uri.request_uri)
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("[ReverseGeocodeAddress] HTTP #{response.code} for #{@lat},#{@lng}")
      return [nil, true]
    end

    json = JSON.parse(response.body)

    case json["status"]
    when "OK"
      [strip_country_suffix(json.dig("results", 0, "formatted_address")), false]
    when "ZERO_RESULTS"
      [nil, false]
    else
      Rails.logger.warn("[ReverseGeocodeAddress] Unexpected status=#{json["status"]} for #{@lat},#{@lng}")
      [nil, true]
    end
  rescue StandardError => e
    Rails.logger.warn("[ReverseGeocodeAddress] #{e.class}: #{e.message} for #{@lat},#{@lng}")
    [nil, true]
  end

  def strip_country_suffix(address)
    address&.sub(/, USA\z/, "")
  end
end
