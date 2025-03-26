require 'rails_helper'
require 'rgeo'
require 'rgeo/geo_json'

CBD_WARD_SECTION = "34CBD"

RSpec.describe 'Zone file validation' do
  let(:file_path) { "db/data/Street Sweeping Zones - #{year}.geojson" }
  let(:year) { Time.current.year }

  it 'contains valid geojson data' do
    errors = []

    File.open(file_path, "r") do |f|
      RGeo::GeoJSON.decode(f, geo_factory: RGeo::Cartesian.simple_factory).each do |object|
        is_cbd_ward_section = object.properties["ward_section"] == CBD_WARD_SECTION
        
        ward_section = object.properties["ward_section"]
        has_ward_section = ward_section.to_i > 0 || is_cbd_ward_section
        ward = object.properties["ward"]
        has_ward = ward.to_i > 0
        section = object.properties["section"]
        has_section = section.to_i > 0 || is_cbd_ward_section
        area_shape = object.geometry

        unless [has_ward, has_section, area_shape].all?
          errors << { has_ward: has_ward, ward: ward, has_section: has_section, section: section, object: object }
        end

        # Validate WARD SECTION length
        errors << "Invalid WARD SECTION length: #{ward_section}" unless ward_section.length == 4 || is_cbd_ward_section

        # Validate WARD SECTION against WARD
        errors << "Invalid WARD SECTION v. WARD: #{ward_section} v. #{ward}" unless ward_section[0..1] == ward

        # Validate WARD SECTION against SECTION
        errors << "Invalid WARD SECTION v. SECTION: #{ward_section} v. #{section}" unless ward_section[-2..-1] == section

        # Validate WARD
        errors << "Invalid WARD: #{ward}" unless ward.to_i.between?(1, 50)
      end

      expect(errors).to be_empty, errors
    end
  end
end
