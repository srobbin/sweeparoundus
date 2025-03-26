require 'rails_helper'
require 'csv'

RSpec.describe 'Schedule vs. Zone Validation' do
  let(:schedule_file_path) { "db/data/Street_Sweeping_Schedule_-_#{year}.csv" }
  let(:zone_file_path) { "db/data/Street Sweeping Zones - #{year}.geojson" }
  let(:year) { Time.current.year }

  let(:zone_file_content) do
    File.read(zone_file_path)
  end

  it 'checks that each ward_section from the schedule appears exactly once in the geojson data' do
    errors = []
    already_checked = {}

    CSV.foreach(schedule_file_path, headers: true) do |row|
      ward_section = row['WARD SECTION (CONCATENATED)']

      next if already_checked[ward_section]

      search_term = "\"ward_section\":\"#{ward_section}\""
      occurrences = zone_file_content.scan(search_term).count
      errors << "Expected #{search_term} to appear exactly once, but found #{occurrences} times" unless occurrences == 1

      already_checked[ward_section] = true
    end

    expect(errors).to be_empty, errors.join("\n")
  end
end