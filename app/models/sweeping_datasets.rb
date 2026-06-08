# Per-year Chicago Data Portal dataset configuration for the street sweeping
# Schedule (CSV) and Zones (GeoJSON). The dataset IDs and canonical filenames
# change every year, so this map is updated as part of annual maintenance
# (add next year's entry before the City publishes, or the in-season
# CheckSweepingDataUpdatesJob will alert that no config exists for the year).
#
# The canonical paths intentionally match what specs, SeedYearlyData, and the
# runtime all read: db/data/Street_Sweeping_Schedule_-_<year>.csv and
# db/data/Street Sweeping Zones - <year>.geojson.
module SweepingDatasets
  Config = Data.define(:year, :schedule_id, :zones_id) do
    def schedule_path = "db/data/Street_Sweeping_Schedule_-_#{year}.csv"
    def zones_path    = "db/data/Street Sweeping Zones - #{year}.geojson"
  end

  CONFIG = {
    2026 => Config.new(year: 2026, schedule_id: "u5ai-3efk", zones_id: "2r7q-emq3")
  }.freeze

  # Socrata views metadata (rowsUpdatedAt, name) for both datasets.
  METADATA_URL = "https://data.cityofchicago.org/api/views/%<id>s.json"

  # Schedule export MUST use the rows.csv export so column headers are the
  # human names the specs read ("WARD SECTION (CONCATENATED)" etc.). The plain
  # /resource/<id>.csv endpoint returns API field names and would break specs.
  SCHEDULE_CSV_URL = "https://data.cityofchicago.org/api/views/%<id>s/rows.csv?accessType=DOWNLOAD"
  ZONES_GEOJSON_URL = "https://data.cityofchicago.org/api/geospatial/%<id>s?method=export&format=GeoJSON"

  # Raised when no dataset config exists for the requested year (e.g. next
  # year's IDs haven't been added yet). The job treats this as an "availability"
  # signal, not a transient error.
  MissingConfigError = Class.new(KeyError)

  module_function

  def for(year = Time.current.year)
    CONFIG.fetch(year)
  rescue KeyError
    raise MissingConfigError, "No sweeping dataset config for #{year}"
  end

  def metadata_url(id) = format(METADATA_URL, id: id)
  def schedule_csv_url(id) = format(SCHEDULE_CSV_URL, id: id)
  def zones_geojson_url(id) = format(ZONES_GEOJSON_URL, id: id)
end
