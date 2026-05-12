require "uri"

# Builds a Google Static Maps URL showing the subscriber's pin and a
# filled polygon for their sweep area boundary.
# Returns nil if any required input (coords, shape, or API key) is missing.
class AlertStaticMap
  BASE_URL = "https://maps.googleapis.com/maps/api/staticmap".freeze
  SIZE = "480x320".freeze
  WIDTH = 480
  SCALE = 2
  MAP_TYPE = "roadmap".freeze

  HOME_MARKER_STYLE = "color:blue|label:H".freeze

  FILL_COLOR = "0xFF6D0033".freeze
  BORDER_COLOR = "0xE65100BB".freeze
  BORDER_WEIGHT = 2

  # Google Static Maps has a ~16 KB URL limit; cap polygon detail to stay safe.
  MAX_POLYGON_POINTS = 80

  def initialize(alert:, area:)
    @alert = alert
    @area = area
  end

  def url
    return nil if api_key.blank?
    return nil if alert_lat.nil? || alert_lng.nil?
    return nil if @area&.shape.nil?

    coords = extract_polygon_coords
    return nil if coords.empty?

    parts = []
    parts << "size=#{SIZE}"
    parts << "scale=#{SCALE}"
    parts << "maptype=#{MAP_TYPE}"
    parts << marker_param(HOME_MARKER_STYLE, alert_lat, alert_lng)
    parts << polygon_path_param(coords)
    parts << "key=#{encode(api_key)}"
    "#{BASE_URL}?#{parts.join('&')}"
  end

  private

  def alert_lat = @alert.lat
  def alert_lng = @alert.lng

  def extract_polygon_coords
    shape = @area.shape
    ring = case shape.geometry_type.type_name
           when "Polygon"      then shape.exterior_ring
           when "MultiPolygon" then shape.first&.exterior_ring
           end
    return [] unless ring

    points = ring.points.map { |p| [p.y, p.x] } # [lat, lng]
    downsample(points)
  end

  def downsample(points)
    return points if points.size <= MAX_POLYGON_POINTS

    step = (points.size - 1).to_f / (MAX_POLYGON_POINTS - 1)
    (0...MAX_POLYGON_POINTS).map { |i| points[(i * step).round] }
  end

  def polygon_path_param(coords)
    encoded_path = encode_polyline(coords)
    style = "fillcolor:#{FILL_COLOR}|color:#{BORDER_COLOR}|weight:#{BORDER_WEIGHT}|enc:#{encoded_path}"
    "path=#{encode(style)}"
  end

  # Google Encoded Polyline Algorithm
  # https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  def encode_polyline(coords)
    prev_lat = 0
    prev_lng = 0
    result = +""

    coords.each do |lat, lng|
      lat_e5 = (lat.to_f * 1e5).round
      lng_e5 = (lng.to_f * 1e5).round

      result << encode_signed(lat_e5 - prev_lat)
      result << encode_signed(lng_e5 - prev_lng)

      prev_lat = lat_e5
      prev_lng = lng_e5
    end

    result
  end

  def encode_signed(num)
    sgn = num << 1
    sgn = ~sgn if num.negative?
    encode_unsigned(sgn)
  end

  def encode_unsigned(num)
    encoded = +""
    while num >= 0x20
      encoded << ((num & 0x1f | 0x20) + 63).chr
      num >>= 5
    end
    encoded << (num + 63).chr
  end

  def marker_param(style, lat, lng)
    "markers=#{encode("#{style}|#{coord(lat)},#{coord(lng)}")}"
  end

  def coord(value)
    case value
    when BigDecimal then value.to_s("F")
    else value.to_s
    end
  end

  def encode(value)
    URI.encode_www_form_component(value)
  end

  def api_key
    ENV["GOOGLE_MAPS_FRONTEND_API_KEY"]
  end
end
