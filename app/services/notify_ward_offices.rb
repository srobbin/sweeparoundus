require "csv"

class NotifyWardOffices
  attr_reader :write, :year

  # NotifyWardOffices.new(write: false, year: Time.current.year.to_s).call
  def initialize(write: false, year: Time.current.year.to_s)
    @write = write
    @year = year
  end

  def call
    raise "SITE_NAME and SITE_URL must be set" if ENV["SITE_NAME"].blank? || ENV["SITE_URL"].blank?

    table = read_csv
    eligible = eligible_offices(table)
    skipped = table.count { |row| notified?(row) }

    puts "#{skipped} office(s) already notified, skipping" if skipped > 0

    return "TEST: #{eligible.size} ward office(s) would be notified" unless write

    notified = []
    eligible.each_with_index do |office, index|
      puts "#{index + 1}/#{eligible.size} notifying Ward #{office[:ward]} (#{office[:email]})"
      begin
        WardOfficeMailer.with(
          name: office[:name],
          email: office[:email],
          ward: office[:ward],
        ).schedules_live.deliver_later
        notified << office
      rescue => e
        puts "FAILED Ward #{office[:ward]} (#{office[:email]}): #{e.message}"
      end
    end

    mark_as_notified(table, notified) if notified.any?

    "SUCCESS: #{notified.size} ward office(s) notified"
  end

  private

  def csv_path
    @csv_path ||= Rails.root.join("db", "data", "Ward_Offices_#{year}.csv")
  end

  def read_csv
    raise "CSV not found: #{csv_path}" unless File.exist?(csv_path)
    CSV.read(csv_path, headers: true)
  end

  def eligible_offices(table)
    offices = []

    table.each do |row|
      email = row["EMAIL"]&.strip
      next if email.blank?
      next if notified?(row)

      alderman = row["ALDERMAN"]&.strip
      last_name = alderman&.split(",")&.first&.strip
      ward = row["WARD"]&.strip

      offices << { name: last_name, email: email, ward: ward }
    end

    offices
  end

  def notified?(row)
    row["NOTIFIED"]&.strip&.downcase == "true"
  end

  def mark_as_notified(table, notified_offices)
    notified_emails = notified_offices.map { |o| o[:email] }

    headers = table.headers
    headers << "NOTIFIED" unless headers.include?("NOTIFIED")

    table.each do |row|
      email = row["EMAIL"]&.strip
      row["NOTIFIED"] = "true" if notified_emails.include?(email)
    end

    CSV.open(csv_path, "w", force_quotes: true) do |csv|
      csv << headers
      table.each do |row|
        csv << headers.map { |h| row[h] }
      end
    end
  end
end
