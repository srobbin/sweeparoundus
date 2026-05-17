class FindCdotPermitAffectedAlerts
  PROXIMITY_THRESHOLD_FEET = 350
  METERS_PER_FOOT = 0.3048
  PROXIMITY_THRESHOLD_METERS = PROXIMITY_THRESHOLD_FEET * METERS_PER_FOOT

  # Approximate feet per Chicago street number (nominal is 6.6). Using 8
  # adds margin so the pre-filter always includes everything the precise
  # 350 ft line check would.
  FEET_PER_STREET_NUMBER = 8

  AffectedAlert = Struct.new(:alert, :distance_feet, keyword_init: true)

  # Geocoded segment endpoints, read from the permit. May be equal
  # (degenerate line) if only one address geocoded. Both nil if the
  # permit couldn't be geolocated.
  attr_reader :line_from, :line_to

  def initialize(permit:)
    @permit = permit
    @line_from = nil
    @line_to = nil
    @pre_filter_skipped = false
  end

  # True when #call short-circuited because no alerts exist near the
  # permit's CDOT point, so the line query was skipped entirely.
  def pre_filter_skipped?
    @pre_filter_skipped
  end

  # Returns AffectedAlert structs sorted by distance, or [] if the permit
  # has no stored segment coordinates or no alerts are within range.
  def call
    if no_nearby_candidates?
      @pre_filter_skipped = true
      Rails.logger.info(
        "[FindCdotPermitAffectedAlerts] Permit #{@permit.unique_key} " \
        "skipped: no candidate alerts within #{pre_filter_radius_feet} ft of permit point"
      )
      return []
    end

    line_wkt = build_line_wkt
    return [] if line_wkt.nil?

    rows = query_alerts(line_wkt).to_a
    rows.map do |row|
      AffectedAlert.new(
        alert: row,
        distance_feet: (row.distance_meters / METERS_PER_FOOT).round
      )
    end
  end

  private

  # Quick point-radius check using the permit's CDOT location to skip
  # the line query when no alert is near enough. Radius = segment_length +
  # PROXIMITY_THRESHOLD_FEET so it's always a superset of the precise check.
  # Returns false (falls through) if the permit has no usable coordinates.
  def no_nearby_candidates?
    return false if @permit.location.nil?

    point_sql = Alert.sanitize_sql_array([
      "ST_GeographyFromText(?)",
      "SRID=4326;#{@permit.location.as_text}"
    ])

    !candidate_alerts
      .where("ST_DWithin(alerts.location, #{point_sql}, ?)", pre_filter_radius_meters)
      .exists?
  end

  def pre_filter_radius_feet
    return PROXIMITY_THRESHOLD_FEET if @permit.street_number_from.blank? ||
                                       @permit.street_number_to.blank?

    range = (@permit.street_number_to.to_i - @permit.street_number_from.to_i).abs
    range * FEET_PER_STREET_NUMBER + PROXIMITY_THRESHOLD_FEET
  end

  def pre_filter_radius_meters
    pre_filter_radius_feet * METERS_PER_FOOT
  end

  def build_line_wkt
    @line_from = @permit.segment_from
    @line_to = @permit.segment_to

    if @line_from.nil? && @line_to.nil?
      Rails.logger.warn(
        "[FindCdotPermitAffectedAlerts] Permit #{@permit.unique_key} " \
        "has no pre-geocoded segment coordinates"
      )
      Sentry.capture_message(
        "[FindCdotPermitAffectedAlerts] Permit has no pre-geocoded segment coordinates",
        level: :warning,
        contexts: { permit: { unique_key: @permit.unique_key, permit_id: @permit.id } },
      )
      return nil
    end

    @line_from ||= @line_to
    @line_to   ||= @line_from

    "LINESTRING(#{@line_from.lng} #{@line_from.lat}, #{@line_to.lng} #{@line_to.lat})"
  end

  def query_alerts(line_wkt)
    line_sql = Alert.sanitize_sql_array([ "ST_GeographyFromText(?)", "SRID=4326;#{line_wkt}" ])

    candidate_alerts
      .where("ST_DWithin(alerts.location, #{line_sql}, ?)", PROXIMITY_THRESHOLD_METERS)
      .select("alerts.*", Arel.sql("ST_Distance(alerts.location, #{line_sql}) AS distance_meters"))
      .order(Arel.sql("distance_meters ASC, alerts.id ASC"))
  end

  # Single definition of "alerts that can receive a permit notification" so
  # the cheap pre-filter and the precise line query stay in lockstep.
  def candidate_alerts
    Alert
      .confirmed
      .with_street_address
      .with_location
      .permit_notifications_enabled
  end
end
