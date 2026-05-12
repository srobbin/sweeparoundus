class FindAdjacentSweepAreas
  EDGE_THRESHOLD_FEET = 350
  METERS_PER_FOOT = 0.3048
  EDGE_THRESHOLD_METERS = EDGE_THRESHOLD_FEET * METERS_PER_FOOT
  MAX_NEIGHBORS = 3

  Neighbor = Struct.new(:area, :distance_feet, :direction, :nearest_address, keyword_init: true)

  COMPASS_POINTS = %w[N NE E SE S SW W NW].freeze

  # ReverseGeocodeAddress uses 2s open + 2s read HTTP timeouts; 5s is
  # generous enough to never race the happy path but still caps the
  # worst-case wall-clock cost of a DNS stall or similar hang.
  GEOCODE_THREAD_TIMEOUT = 5

  def initialize(area:, lat:, lng:)
    @area = area
    @lat = Float(lat)
    @lng = Float(lng)
  end

  def call
    rows = find_neighbors.to_a
    threads = rows.map do |row|
      Thread.new { ReverseGeocodeAddress.new(lat: row.closest_lat, lng: row.closest_lng).call }
    end
    addresses = threads.map { |t| join_thread(t) }
    rows.zip(addresses).map { |row, addr| build_neighbor(row, addr) }
  end

  private

  def find_neighbors
    Area.where.not(id: @area.id)
      .includes(:sweeps)
      .where(
        "ST_DWithin(ST_SetSRID(shape, 4326)::geography, #{geography_point_sql}, ?)",
        EDGE_THRESHOLD_METERS
      )
      .select(
        "areas.*",
        Arel.sql("ST_Distance(ST_SetSRID(shape, 4326)::geography, #{geography_point_sql}) AS distance_meters"),
        Arel.sql("ST_Y(ST_ClosestPoint(shape, #{geometry_point_sql})) AS closest_lat"),
        Arel.sql("ST_X(ST_ClosestPoint(shape, #{geometry_point_sql})) AS closest_lng"),
        Arel.sql("degrees(ST_Azimuth(#{geography_point_sql}, ST_SetSRID(ST_ClosestPoint(shape, #{geometry_point_sql}), 4326)::geography)) AS azimuth_deg")
      )
      .order(Arel.sql("distance_meters ASC, areas.id ASC"))
      .limit(MAX_NEIGHBORS)
  end

  def geometry_point_sql
    @geometry_point_sql ||= Area.sanitize_sql_array(
      ["ST_MakePoint(?, ?)", @lng, @lat]
    )
  end

  def geography_point_sql
    @geography_point_sql ||= "ST_SetSRID(#{geometry_point_sql}, 4326)::geography"
  end

  def join_thread(thread)
    unless thread.join(GEOCODE_THREAD_TIMEOUT)
      thread.kill
      Rails.logger.warn("[FindAdjacentSweepAreas] Geocode thread timed out")
      Sentry.capture_message("[FindAdjacentSweepAreas] Geocode thread timed out", level: :warning,
        contexts: { find_adjacent: { area_id: @area.id } })
      return nil
    end
    thread.value
  rescue StandardError => e
    Rails.logger.warn("[FindAdjacentSweepAreas] Geocode thread failed: #{e.class}: #{e.message}")
    Sentry.capture_exception(e, contexts: { find_adjacent: { area_id: @area.id } })
    nil
  end

  def build_neighbor(row, address)
    Neighbor.new(
      area: row.decorate,
      distance_feet: (row.distance_meters / METERS_PER_FOOT).round,
      direction: azimuth_to_compass(row.azimuth_deg),
      nearest_address: address
    )
  end

  def azimuth_to_compass(degrees)
    return "N" if degrees.nil?

    index = ((degrees % 360) / 45.0).round % 8
    COMPASS_POINTS[index]
  end
end
