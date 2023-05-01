require "csv"

return unless Rails.env.development?

puts "Create an admin user"
AdminUser.create!(
  email: "admin@example.com",
  password: "password",
  password_confirmation: "password",
)

puts "Destroying old data"
Sweep.delete_all
Area.delete_all

puts "Importing GeoJSON"
File.open("db/data/Street Sweeping Zones - 2023.geojson", "r") do |f|
  RGeo::GeoJSON.decode(f, geo_factory: RGeo::Cartesian.simple_factory).each do |object|
    ward_number = object.properties["ward"]
    area_number = object.properties["section"]
    area_shape = object.geometry

    next unless ward_number && area_number && area_shape

    puts "Ward #{"%02d" % ward_number}, Area #{"%02d" % area_number}"
    area = Area.find_or_initialize_by(number: area_number, ward: ward_number)
    area.update!(shape: area_shape, shortcode: "W#{ward_number}A#{area_number}")
  end
end

puts "Importing Schedule"
CSV.foreach("db/data/Street_Sweeping_Schedule_-_2023.csv", headers: true).each do |row|
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
