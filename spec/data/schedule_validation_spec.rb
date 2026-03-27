require 'rails_helper'
require 'csv'

RSpec.describe 'Schedule file validation' do
  let(:file_path) { "db/data/Street_Sweeping_Schedule_-_#{year}.csv" }
  let(:year) { Time.current.year }
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
      errors << "Invalid WARD SECTION v. SECTION: #{ward_section} v. #{section}" unless ward_section[-2..-1] == section

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

      # Validate DATES are in ascending order
      sorted_dates = dates.sort
      unless dates == sorted_dates
        errors << "Dates not in ascending order for Ward #{ward}, Section #{section}, #{month_name}: #{row['DATES']}"
      end
    end

    expect(errors).to be_empty, errors.join("\n")
  end

  it 'has no duplicate rows' do
    seen = {}

    CSV.foreach(file_path, headers: true).with_index(2) do |row, line|
      key = row.fields.join('|')

      if seen[key]
        seen[key] << line
      else
        seen[key] = [line]
      end
    end

    duplicates = seen.select { |_, lines| lines.size > 1 }

    errors = duplicates.map do |key, lines|
      "Duplicate row on lines #{lines.join(', ')}: #{key}"
    end

    expect(errors).to be_empty, errors.join("\n")
  end

  it 'has no duplicate ward_section + month combinations' do
    seen = {}

    CSV.foreach(file_path, headers: true).with_index(2) do |row, line|
      ward_section = row['WARD SECTION (CONCATENATED)']
      month_number = row['MONTH NUMBER']
      key = "#{ward_section}|#{month_number}"

      if seen[key]
        seen[key] << line
      else
        seen[key] = [line]
      end
    end

    duplicates = seen.select { |_, lines| lines.size > 1 }

    errors = duplicates.map do |key, lines|
      ward_section, month = key.split('|')
      "Ward section #{ward_section}, month #{month} appears on lines #{lines.join(', ')}"
    end

    expect(errors).to be_empty, errors.join("\n")
  end

  it 'has at least 2 months of sweeping per ward section' do
    month_counts = Hash.new(0)

    CSV.foreach(file_path, headers: true) do |row|
      month_counts[row['WARD SECTION (CONCATENATED)']] += 1
    end

    errors = month_counts.select { |_, count| count < 2 }.map do |ward_section, count|
      "Ward section #{ward_section} only has #{count} month(s)"
    end

    expect(errors).to be_empty, errors.join("\n")
  end

  it 'has no gaps in section numbering within a ward' do
    sections_by_ward = Hash.new { |h, k| h[k] = [] }

    CSV.foreach(file_path, headers: true) do |row|
      ward = row['WARD'].to_i
      section = row['SECTION'].to_i
      sections_by_ward[ward] << section
    end

    errors = []

    sections_by_ward.each do |ward, sections|
      unique = sections.uniq.sort
      expected = (unique.first..unique.last).to_a
      missing = expected - unique
      missing.each do |section|
        errors << "Ward %02d is missing section %02d (sections range from %02d to %02d)" %
          [ward, section, unique.first, unique.last]
      end
    end

    expect(errors).to be_empty, errors.join("\n")
  end

  it 'has no section whose schedule is a strict subset of another in the same ward' do
    schedules = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }

    CSV.foreach(file_path, headers: true) do |row|
      ward = row['WARD']
      section = row['SECTION']
      month_number = row['MONTH NUMBER']
      dates = row['DATES']
      schedules[ward][section][month_number] = dates
    end

    errors = []

    schedules.each do |ward, sections|
      section_ids = sections.keys
      section_ids.combination(2).each do |s1, s2|
        sched1 = sections[s1]
        sched2 = sections[s2]

        if sched1.size < sched2.size && sched1.all? { |month, dates| sched2[month] == dates }
          missing = (sched2.keys - sched1.keys).sort
          errors << "Ward #{ward}, section #{s1} is a strict subset of section #{s2} (missing month(s): #{missing.join(', ')})"
        elsif sched2.size < sched1.size && sched2.all? { |month, dates| sched1[month] == dates }
          missing = (sched1.keys - sched2.keys).sort
          errors << "Ward #{ward}, section #{s2} is a strict subset of section #{s1} (missing month(s): #{missing.join(', ')})"
        end
      end
    end

    expect(errors).to be_empty, errors.join("\n")
  end
end
