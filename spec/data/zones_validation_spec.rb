require 'rails_helper'
require 'rgeo'
require 'rgeo/geo_json'

# Ward 34 has a special zone with no sweeping data, included only for shape purposes.
# It was originally named 34CBD, then renamed to 34BD, and later to 34NA.
NON_SWEEPING_WARD_SECTIONS = %w[34BD 34NA].freeze

RSpec.describe 'Zone file validation' do
  let(:file_path) { "db/data/Street Sweeping Zones - #{year}.geojson" }
  let(:year) { Time.current.year }

  it 'contains valid geojson data' do
    errors = []

    File.open(file_path, "r") do |f|
      RGeo::GeoJSON.decode(f, geo_factory: RGeo::Cartesian.simple_factory).each do |object|
        ward_section = object.properties["ward_section"]
        is_non_sweeping = NON_SWEEPING_WARD_SECTIONS.include?(ward_section)

        ward = object.properties["ward"]
        has_ward = ward.to_i > 0
        section = object.properties["section"]
        has_section = section.to_i > 0 || is_non_sweeping
        area_shape = object.geometry

        unless [has_ward, has_section, area_shape].all?
          errors << { has_ward: has_ward, ward: ward, has_section: has_section, section: section, object: object }
        end

        # Validate WARD SECTION length
        errors << "Invalid WARD SECTION length: #{ward_section}" unless ward_section.length == 4 || is_non_sweeping

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
