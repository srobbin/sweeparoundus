require "csv"

# Looks up a ward's alderperson contact info from db/data/Ward_Offices_<year>.csv.
# Used to personalize one-off subscriber emails (e.g. the 2026 extended-season
# notice) so each recipient can contact their own alderperson.
class WardOfficeLookup
  attr_reader :year

  def initialize(year: Time.current.year.to_s)
    @year = year
  end

  def self.for_ward(ward, year: Time.current.year.to_s)
    new(year: year).for_ward(ward)
  end

  def for_ward(ward)
    return nil if ward.blank?

    row = table.find { |r| r["WARD"]&.strip == ward.to_s.strip }
    return nil unless row

    {
      ward: row["WARD"]&.strip,
      alderperson: full_name(row["ALDERMAN"]),
      phone: row["WARD PHONE"]&.strip.presence,
      email: row["EMAIL"]&.strip.presence,
      website: row["WEBSITE"]&.strip.presence
    }
  end

  private

  def csv_path
    Rails.root.join("db", "data", "Ward_Offices_#{year}.csv")
  end

  def table
    @table ||= CSV.read(csv_path, headers: true)
  end

  # CSV stores "Last, First" (e.g. "La Spata, Daniel", "Cardona, Jr., Felix").
  def full_name(alderman)
    parts = alderman.to_s.split(",").map(&:strip).reject(&:blank?)
    return alderman.to_s.strip if parts.size < 2

    first_name = parts.last
    last_name = parts[0...-1].join(" ")
    "#{first_name} #{last_name}".strip
  end
end
