class SeedYearlyData
  attr_reader :write, :year

  # SeedYearlyData.new(write: false, year: Time.current.year.to_s).call
  def initialize(write: false, year:)
    @write = write
    @year = year
  end

  def call
    unless write
      import_geojson_data
      import_schedule_data
      return "TEST: #{Sweep.count} sweeps and #{Area.count} areas to be deleted; geojson and schedule files opened without error"
    end

    ActiveRecord::Base.transaction do
      destroy_old_sweep_data
      destroy_old_area_data
      import_geojson_data
      import_schedule_data
      "SUCCESS: #{Area.count} areas and #{Sweep.count} sweeps created from #{year} files"
    end
  rescue => e
    if write
      "ERROR: Failed to seed yearly data - #{e.message}"
    else
      "TEST ERROR: #{e.message}"
    end
  end

  private

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
    
        next unless [write, ward_number, area_number, area_shape].all?
    
        puts "Ward #{"%02d" % ward_number}, Area #{"%02d" % area_number}"
        area = Area.find_or_initialize_by(number: area_number, ward: ward_number)
        area.update!(shape: area_shape, shortcode: "W#{ward_number}A#{area_number}")
      end
    end
  end

  def import_schedule_data
    puts "Importing Schedule"
    CSV.foreach("db/data/Street_Sweeping_Schedule_-_#{year}.csv", headers: true).each do |row|
      puts row.to_s
      area = Area.find_by(number: row["SECTION"], ward: row["WARD"])
      month = row["MONTH NUMBER"].strip
      dates = row["DATES"].split(",").reject{ |d| d.strip.blank? }.map do |day|
        Date.new(Date.current.year, month.to_i, day.to_i)
      end.uniq.sort

      clusters = []
      cluster_index = 0
      dates.each_with_index do |date, index|
        clusters[cluster_index] ||= []
        last_date = clusters[cluster_index].last
        
        if last_date && date > last_date + 3.days
          cluster_index += 1
          clusters[cluster_index] ||= []
        end

        clusters[cluster_index] << date
      end

      next unless write

      clusters.each do |cluster|
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
end
