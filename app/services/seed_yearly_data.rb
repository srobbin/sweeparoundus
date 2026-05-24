class SeedYearlyData
  attr_reader :write, :year, :skip_geojson

  # SeedYearlyData.new(write: false, year: Time.current.year.to_s).call
  #
  # Pass skip_geojson: true to refresh sweep data from the CSV without
  # touching Area records. Useful for mid-season schedule corrections where
  # the GeoJSON zones haven't changed.
  def initialize(write: false, year:, skip_geojson: false)
    @write = write
    @year = year
    @skip_geojson = skip_geojson
  end

  def call
    unless write
      import_geojson_data unless skip_geojson
      import_schedule_data
      return dry_run_message
    end

    ActiveRecord::Base.transaction do
      destroy_old_sweep_data
      unless skip_geojson
        destroy_old_area_data
        import_geojson_data
      end
      import_schedule_data
      success_message
    end
  rescue => e
    if write
      "ERROR: Failed to seed yearly data - #{e.message}"
    else
      "TEST ERROR: #{e.message}"
    end
  end

  private

  def dry_run_message
    deletions = [ "#{Sweep.count} sweeps" ]
    deletions << "#{Area.count} areas" unless skip_geojson
    files = skip_geojson ? "schedule file" : "geojson and schedule files"
    "TEST: #{deletions.join(' and ')} to be deleted; #{files} opened without error"
  end

  def success_message
    if skip_geojson
      "SUCCESS: #{Sweep.count} sweeps re-created from #{year} schedule file (areas unchanged)"
    else
      "SUCCESS: #{Area.count} areas and #{Sweep.count} sweeps created from #{year} files"
    end
  end

  def destroy_old_sweep_data
    puts "Destroying old sweep data"
    Sweep.destroy_all
  end

  def destroy_old_area_data
    puts "Destroying old area data"
    Area.destroy_all
  end

  def import_geojson_data
    puts "Importing GeoJSON"
    File.open("db/data/Street Sweeping Zones - #{year}.geojson", "r") do |f|
      RGeo::GeoJSON.decode(f, geo_factory: RGeo::Cartesian.simple_factory).each do |object|
        ward_number = object.properties["ward"].to_i
        area_number = object.properties["section"].to_i
        area_shape = object.geometry

        next unless [ write, ward_number, area_number, area_shape ].all?

        puts "Ward #{"%02d" % ward_number}, Area #{"%02d" % area_number}"
        area = Area.find_or_initialize_by(number: area_number, ward: ward_number)
        area.update!(shape: area_shape, shortcode: "W#{ward_number}A#{area_number}")
      end
    end
  end

  def import_schedule_data
    puts "Importing Schedule"
    area_dates = collect_area_dates
    return unless write

    area_dates.each do |area, dates|
      cluster_dates(dates).each do |cluster|
        Sweep.find_or_create_by!(
          area: area,
          date_1: cluster[0],
          date_2: cluster[1],
          date_3: cluster[2],
          date_4: cluster[3],
        )
      end
    end
  end

  # Build an `area -> [Date, ...]` map by reading every row of the schedule
  # CSV. We aggregate dates per area across all months before clustering so
  # that month-boundary pairs (e.g. Jun 30 + Jul 1) cluster together instead
  # of being persisted as two separate single-date Sweep records.
  def collect_area_dates
    map = Hash.new { |h, k| h[k] = [] }

    CSV.foreach("db/data/Street_Sweeping_Schedule_-_#{year}.csv", headers: true) do |row|
      area = Area.find_by(number: row["SECTION"], ward: row["WARD"])
      next unless area

      month = row["MONTH NUMBER"].strip
      row["DATES"].split(",").each do |day|
        day = day.strip
        next if day.blank?

        map[area] << Date.new(Date.current.year, month.to_i, day.to_i)
      end
    end

    map.transform_values { |dates| dates.uniq.sort }
  end

  # Group a sorted list of dates into clusters where each subsequent date is
  # within 3 days of the previous one in the same cluster. Operates purely on
  # the date list, so it doesn't care about month boundaries.
  def cluster_dates(dates)
    clusters = []
    current = nil

    dates.each do |date|
      if current.nil? || date > current.last + 3.days
        current = [ date ]
        clusters << current
      else
        current << date
      end
    end

    clusters
  end
end
