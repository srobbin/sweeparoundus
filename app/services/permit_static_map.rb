require "uri"

# Builds a Google Static Maps URL showing the subscriber's pin and a line
# connecting the two endpoints of a CDOT permit's construction segment.
# Returns nil if any required input (coords, endpoints, or API key) is missing.
class PermitStaticMap
  BASE_URL = "https://maps.googleapis.com/maps/api/staticmap".freeze
  # Small enough to work as a supporting visual when multiple maps are
  # stacked in a single email.
  SIZE = "480x320".freeze
  WIDTH = 480
  SCALE = 2 # retina-quality so the image still looks crisp at SIZE px wide
  MAP_TYPE = "roadmap".freeze

  HOME_MARKER_STYLE = "color:blue|label:H".freeze
  PERMIT_MARKER_STYLE_A = "color:red|label:A".freeze
  PERMIT_MARKER_STYLE_B = "color:red|label:B".freeze
  PERMIT_POINT_MARKER_STYLE = "color:red|label:P".freeze
  # Translucent red, drawn thick so it reads as a "construction zone" line
  # without overpowering the residential pin.
  PATH_STYLE = "color:0xff0000cc|weight:5".freeze

  def initialize(alert:, line_from:, line_to:)
    @alert = alert
    @line_from = line_from
    @line_to = line_to
  end

  def url
    return nil if api_key.blank?
    return nil if alert_lat.nil? || alert_lng.nil?
    return nil if @line_from.nil? || @line_to.nil?

    parts = []
    parts << "size=#{SIZE}"
    parts << "scale=#{SCALE}"
    parts << "maptype=#{MAP_TYPE}"
    parts << marker_param(HOME_MARKER_STYLE, alert_lat, alert_lng)

    if segment?
      parts << marker_param(PERMIT_MARKER_STYLE_A, @line_from.lat, @line_from.lng)
      parts << marker_param(PERMIT_MARKER_STYLE_B, @line_to.lat, @line_to.lng)
      parts << "path=#{encode("#{PATH_STYLE}|#{coord(@line_from.lat)},#{coord(@line_from.lng)}|#{coord(@line_to.lat)},#{coord(@line_to.lng)}")}"
    else
      # Degenerate line (e.g. only one endpoint geocoded): drop a single
      # permit pin instead of trying to draw a zero-length path.
      parts << marker_param(PERMIT_POINT_MARKER_STYLE, @line_from.lat, @line_from.lng)
    end

    parts << "key=#{encode(api_key)}"
    "#{BASE_URL}?#{parts.join('&')}"
  end

  private

  def alert_lat
    @alert.lat
  end

  def alert_lng
    @alert.lng
  end

  def segment?
    coord(@line_from.lat) != coord(@line_to.lat) ||
      coord(@line_from.lng) != coord(@line_to.lng)
  end

  def marker_param(style, lat, lng)
    "markers=#{encode("#{style}|#{coord(lat)},#{coord(lng)}")}"
  end

  # Alert#lat / Alert#lng are stored as BigDecimal, whose default `to_s`
  # is scientific ("0.41942e2"). Force a plain decimal representation so
  # the URL is readable and Static Maps actually accepts it.
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
