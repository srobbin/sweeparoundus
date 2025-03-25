require 'rails_helper'
require 'csv'

RSpec.describe 'Schedule file validation' do
  let(:file_path) { 'db/data/Street_Sweeping_Schedule_-_2025.csv' }
  let(:valid_month_numbers) { (4..11).to_a }
  let(:valid_month_names) { %w[APRIL MAY JUNE JULY AUGUST SEPTEMBER OCTOBER NOVEMBER] }
  let(:days_in_month) { { 4 => 30, 5 => 31, 6 => 30, 7 => 31, 8 => 31, 9 => 30, 10 => 31, 11 => 30 } }

  it 'contains valid values in each column' do
    errors = []

    CSV.foreach(file_path, headers: true) do |row|
      ward_section = row['WARD SECTION (CONCATENATED)']
      ward = row['WARD']
      section = row['SECTION']
      month_name = row['MONTH NAME']
      month_number = row['MONTH NUMBER'].to_i
      dates = row['DATES'].split(',').map(&:to_i)

      # Validate WARD SECTION length
      errors << "Invalid WARD SECTION length: #{ward_section}" unless ward_section.length == 4

      # Validate WARD SECTION against WARD
      errors << "Invalid WARD SECTION v. WARD: #{ward_section} v. #{ward}" unless ward_section[0..1] == ward

      # Validate WARD SECTION against SECTION
      errors << "Invalid WARD SECTION v. SECTION: #{ward_section} v. #{section}" unless ward_section[2..3] == section

      # Validate WARD
      errors << "Invalid WARD: #{ward}" unless ward.to_i.between?(1, 50)

      # Validate MONTH NAME
      errors << "Invalid MONTH NAME: #{month_name}" unless valid_month_names.include?(month_name)

      # Validate MONTH NUMBER
      errors << "Invalid MONTH NUMBER: #{month_number}" unless valid_month_numbers.include?(month_number)

      # Validate DATES
      max_days = days_in_month[month_number]
      dates.each do |date|
        errors << "Invalid date #{date} for month #{month_number}" unless date.between?(1, max_days)
      end

    end

    expect(errors).to be_empty, errors.join("\n")
  end
end
