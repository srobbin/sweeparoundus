require "csv"
require "tempfile"

# NotifyWardOfficesExtendedSeason.new(write: false).call
# One-off 2026 late-season notice: City extended posted sweeping through Dec 17,
# but DSS will not update the open-data schedule.
# Run only one instance at a time. Each enqueue is checkpointed before continuing;
# a crash between enqueueing and checkpointing can still duplicate that notice.
class NotifyWardOfficesExtendedSeason
  attr_reader :write, :year

  NOTIFIED_COLUMN = "EXTENDED_NOTIFIED"

  def initialize(write: false, year: Time.current.year.to_s)
    @write = write
    @year = year
  end

  def call
    raise "SITE_NAME and SITE_URL must be set" if ENV["SITE_NAME"].blank? || ENV["SITE_URL"].blank?

    table = read_csv
    eligible = eligible_offices(table)
    skipped = table.count { |row| notified?(row) }

    puts "#{skipped} office(s) already notified of extended season, skipping" if skipped > 0

    return "TEST: #{eligible.size} ward office(s) would be notified of extended season" unless write

    notified = []
    eligible.each_with_index do |office, index|
      puts "#{index + 1}/#{eligible.size} notifying Ward #{office[:ward]} (#{office[:email]})"
      begin
        job = WardOfficeMailer.with(
          name: office[:name],
          email: office[:email],
          ward: office[:ward],
        ).extended_season_notice.deliver_later
        raise "Extended season notice enqueue aborted" unless job
      rescue => e
        puts "FAILED Ward #{office[:ward]} (#{office[:email]}): #{e.message}"
        Sentry.capture_exception(e, level: :warning, contexts: {
          ward_office: { ward: office[:ward], email: office[:email], year: year, mailer: "extended_season_notice" }
        })
        next
      end

      # Stop if checkpointing fails rather than enqueueing more untracked notices.
      mark_as_notified(table, [ office ])
      notified << office
    end

    "SUCCESS: #{notified.size} ward office(s) notified of extended season"
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
    row[NOTIFIED_COLUMN]&.strip&.downcase == "true"
  end

  def mark_as_notified(table, notified_offices)
    notified_emails = notified_offices.map { |o| o[:email] }

    table.each do |row|
      email = row["EMAIL"]&.strip
      row[NOTIFIED_COLUMN] = notified_emails.include?(email) ? "true" : row[NOTIFIED_COLUMN]
    end

    write_table(table)
  end

  def write_table(table)
    # Keep the replacement on the same filesystem so rename is atomic.
    Tempfile.create([ ".ward_offices", ".csv" ], csv_path.dirname) do |file|
      file.chmod(File.stat(csv_path).mode & 0o777)
      csv = CSV.new(file, force_quotes: true)
      csv << table.headers
      table.each do |row|
        csv << table.headers.map { |h| row[h] }
      end
      csv.flush
      file.fsync
      File.rename(file.path, csv_path)
    end
  end
end
