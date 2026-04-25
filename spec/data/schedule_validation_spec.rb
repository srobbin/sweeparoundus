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

  it 'has no sweeping dates on Saturdays' do
    errors = []

    CSV.foreach(file_path, headers: true).with_index(2) do |row, line|
      month_number = row['MONTH NUMBER'].to_i
      row['DATES'].split(',').each do |d|
        day = d.strip.to_i
        date = Date.new(year, month_number, day)
        if date.saturday?
          errors << "Line #{line}: #{row['WARD SECTION (CONCATENATED)']} has Saturday date #{date.strftime('%B %-d')}"
        end
      end
    end

    expect(errors).to be_empty, errors.join("\n")
  end

  it 'has no sweeping dates on Sundays' do
    errors = []

    CSV.foreach(file_path, headers: true).with_index(2) do |row, line|
      month_number = row['MONTH NUMBER'].to_i
      row['DATES'].split(',').each do |d|
        day = d.strip.to_i
        date = Date.new(year, month_number, day)
        if date.sunday?
          errors << "Line #{line}: #{row['WARD SECTION (CONCATENATED)']} has Sunday date #{date.strftime('%B %-d')}"
        end
      end
    end

    expect(errors).to be_empty, errors.join("\n")
  end

  xit 'has no strange gaps between paired sweep dates' do
    skip 'Not a reliable check — run manually at beginning of season'

    # Sweeps usually occur either on consecutive weekdays (e.g. Mon/Tue) or on
    # consecutive business days split by a weekend, or a weekend plus a Chicago
    # observed holiday (e.g. Fri/Mon, Fri/Tue when Mon is a holiday). For each
    # row with exactly two dates that are within a week of each other (so we
    # don't false-flag rows where the two dates are halves of two separate
    # cross-month pairs grouped into one month), the second date should equal
    # the next business day after the first.
    holidays = chicago_observed_holidays(year)
    errors = []

    CSV.foreach(file_path, headers: true).with_index(2) do |row, line|
      dates = row['DATES'].split(',').map(&:strip).map(&:to_i)
      next unless dates.length == 2

      month = row['MONTH NUMBER'].to_i
      d1 = Date.new(year, month, dates[0])
      d2 = Date.new(year, month, dates[1])
      next if (d2 - d1).to_i > 7

      expected = next_business_day(d1, holidays)
      next if d2 == expected

      errors << "Line #{line}: #{row['WARD SECTION (CONCATENATED)']} #{row['MONTH NAME']} " \
                "#{row['DATES']}: #{d1.strftime('%a %-d')} → #{d2.strftime('%a %-d')} " \
                "is not consecutive business days (expected #{expected.strftime('%a %-d')})"
    end

    expect(errors).to be_empty, errors.join("\n")
  end

  it 'has no section with a month count far below its ward median' do
    months_per_section = Hash.new { |h, k| h[k] = {} }

    CSV.foreach(file_path, headers: true) do |row|
      ward = row['WARD']
      section = row['SECTION']
      months_per_section[ward][section] ||= 0
      months_per_section[ward][section] += 1
    end

    errors = []

    months_per_section.each do |ward, sections|
      counts = sections.values.sort
      median = counts[counts.size / 2]

      sections.each do |section, count|
        if count * 2 < median
          errors << "Ward #{ward}, section #{section} has #{count} month(s) (ward median: #{median})"
        end
      end
    end

    expect(errors).to be_empty, errors.join("\n")
  end

  # Chicago Street & Sanitation generally does not sweep on city-observed
  # federal/Illinois holidays. We include those that fall in Apr–Nov so the
  # pair-gap check accepts Fri/Tue (or similar) when a Mon holiday intervenes.
  def chicago_observed_holidays(year)
    [
      last_weekday_of_month(year, 5, 1),       # Memorial Day (last Mon of May)
      observed(Date.new(year, 6, 19)),         # Juneteenth
      observed(Date.new(year, 7, 4)),          # Independence Day
      nth_weekday_of_month(year, 9, 1, 1),     # Labor Day (1st Mon of Sep)
      nth_weekday_of_month(year, 10, 1, 2),    # Columbus / Indigenous Peoples' Day
      observed(Date.new(year, 11, 11)),        # Veterans Day
      nth_weekday_of_month(year, 11, 4, 4),    # Thanksgiving (4th Thu of Nov)
      nth_weekday_of_month(year, 11, 4, 4) + 1 # Day after Thanksgiving
    ]
  end

  # Federal "observed" rule: Saturday holidays observed Friday, Sunday observed Monday.
  def observed(date)
    return date - 1 if date.saturday?
    return date + 1 if date.sunday?

    date
  end

  def nth_weekday_of_month(year, month, wday, n)
    d = Date.new(year, month, 1)
    d += 1 until d.wday == wday
    d + (7 * (n - 1))
  end

  def last_weekday_of_month(year, month, wday)
    d = Date.new(year, month, -1)
    d -= 1 until d.wday == wday
    d
  end

  def next_business_day(date, holidays)
    d = date + 1
    d += 1 while d.saturday? || d.sunday? || holidays.include?(d)
    d
  end
end
