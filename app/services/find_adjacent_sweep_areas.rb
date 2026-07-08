class FindAdjacentSweepAreas
  EDGE_THRESHOLD_FEET = 350
  METERS_PER_FOOT = 0.3048
  EDGE_THRESHOLD_METERS = EDGE_THRESHOLD_FEET * METERS_PER_FOOT
  MAX_NEIGHBORS = 3

  Neighbor = Struct.new(:area, :distance_feet, :direction, keyword_init: true)

  COMPASS_POINTS = %w[N NE E SE S SW W NW].freeze

  def initialize(area:, lat:, lng:)
    @area = area
    @lat = Float(lat)
    @lng = Float(lng)
  end

  def call
    find_neighbors.map { |row| build_neighbor(row) }
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
        Arel.sql("degrees(ST_Azimuth(#{geography_point_sql}, ST_SetSRID(ST_ClosestPoint(shape, #{geometry_point_sql}), 4326)::geography)) AS azimuth_deg")
      )
      .order(Arel.sql("distance_meters ASC, areas.id ASC"))
      .limit(MAX_NEIGHBORS)
  end

  def geometry_point_sql
    @geometry_point_sql ||= Area.sanitize_sql_array(
      [ "ST_MakePoint(?, ?)", @lng, @lat ]
    )
  end

  def geography_point_sql
    @geography_point_sql ||= "ST_SetSRID(#{geometry_point_sql}, 4326)::geography"
  end

  def build_neighbor(row)
    Neighbor.new(
      area: row.decorate,
      distance_feet: (row.distance_meters / METERS_PER_FOOT).round,
      direction: azimuth_to_compass(row.azimuth_deg)
    )
  end

  def azimuth_to_compass(degrees)
    return "N" if degrees.nil?

    index = ((degrees % 360) / 45.0).round % 8
    COMPASS_POINTS[index]
  end
end
