require "net/http"
require "openssl"

class SyncCdotPermits
  BASE_URL = "https://data.cityofchicago.org/resource/pubx-yq2d.json"
  PAGE_SIZE = 1000
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30
  MAX_RETRIES = 3
  RETRY_BASE_DELAY = 2
  GEOCODE_THROTTLE_DELAY = 0.15
  # Cap any server-supplied Retry-After to keep one slow upstream from
  # parking the worker for an unbounded amount of time.
  MAX_RETRY_AFTER = 60

  HttpError = Class.new(StandardError) do
    attr_reader :code, :retry_after_seconds

    def initialize(message, code: nil, retry_after_seconds: nil)
      super(message)
      @code = code
      @retry_after_seconds = retry_after_seconds
    end
  end

  # Transient network failures we'll retry on. Beyond plain timeouts we
  # see occasional DNS hiccups (SocketError), mid-response disconnects
  # (EOFError, ECONNRESET), and TLS handshake stumbles
  # (OpenSSL::SSL::SSLError) from the upstream. All of these are safe to
  # retry against an idempotent SoQL GET.
  RETRYABLE_NETWORK_ERRORS = [
    Net::OpenTimeout,
    Net::ReadTimeout,
    Errno::ECONNRESET,
    Errno::ETIMEDOUT,
    EOFError,
    SocketError,
    OpenSSL::SSL::SSLError,
  ].freeze

  GEO_FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)
  # CDOT uniquekeys are numeric strings (e.g. "1234567"). We require this
  # both to safely interpolate the keyset cursor into the SoQL `$where`
  # clause and to detect format drift from the API.
  #
  # NOTE on ordering: `uniquekey` is a TEXT column on the CDOT side, so
  # `$order=uniquekey` and `uniquekey>'<cursor>'` are both lexicographic.
  # Today's keys appear to be uniform-width 7-digit strings, which means
  # lexicographic and numeric order coincide. If CDOT ever ships
  # variable-width keys (e.g. a mix of 7- and 8-digit), pagination stays
  # self-consistent (filter and order are both string compares, so we
  # neither skip nor duplicate rows) but the "next page" cursor will
  # jump around in apparent numeric order. The width-drift warning below
  # surfaces that case in logs.
  VALID_UNIQUE_KEY = /\A\d+\z/

  FIELD_MAP = {
    "uniquekey"                    => :unique_key,
    "applicationnumber"            => :application_number,
    "applicationname"              => :application_name,
    "applicationtype"              => :application_type,
    "applicationdescription"       => :application_description,
    "worktype"                     => :work_type,
    "worktypedescription"          => :work_type_description,
    "applicationstatus"            => :application_status,
    "applicationstartdate"         => :application_start_date,
    "applicationenddate"           => :application_end_date,
    "applicationexpiredate"        => :application_expire_date,
    "applicationissueddate"        => :application_issued_date,
    "detail"                       => :detail,
    "parkingmeterpostingorbagging" => :parking_meter_posting_or_bagging,
    "streetnumberfrom"             => :street_number_from,
    "streetnumberto"               => :street_number_to,
    "direction"                    => :direction,
    "streetname"                   => :street_name,
    "suffix"                       => :suffix,
    "placement"                    => :placement,
    "streetclosure"                => :street_closure,
    "ward"                         => :ward,
    "xcoordinate"                  => :x_coordinate,
    "ycoordinate"                  => :y_coordinate,
    "latitude"                     => :latitude,
    "longitude"                    => :longitude,
  }.freeze

  DATE_FIELDS = %i[
    application_start_date application_end_date
    application_expire_date application_issued_date
  ].to_set.freeze

  INTEGER_FIELDS = %i[street_number_from street_number_to ward].to_set.freeze

  # Required to form the line segment used for proximity matching.
  REQUIRED_API_FIELDS = %w[
    streetnumberfrom
    streetnumberto
    direction
    streetname
  ].freeze

  def call
    created = 0
    updated = 0
    unchanged = 0
    skipped = 0
    pages = 0
    last_unique_key = nil
    key_widths = Set.new

    loop do
      rows = fetch_page(last_unique_key)
      pages += 1

      break if rows.empty?

      # Defense in depth: the $where clause already requires these fields, but
      # if the API ever sends an empty string (which is_not_null doesn't catch)
      # we still want to skip the row. Same for malformed uniquekeys.
      usable_rows, unusable_rows = rows.partition { |row| row_usable?(row) }
      if unusable_rows.any?
        skipped += unusable_rows.size
        Rails.logger.warn("[SyncCdotPermits] Skipped #{unusable_rows.size} row(s) " \
                          "with missing required fields or unexpected uniquekey format")
      end

      usable_rows.each { |row| key_widths << row["uniquekey"].length }

      if usable_rows.any?
        sync_time = Time.current
        needs_geocoding = []

        CdotPermit.transaction do
          existing = CdotPermit.where(unique_key: usable_rows.map { |r| r["uniquekey"] })
                               .index_by(&:unique_key)

          unchanged_keys = []

          usable_rows.each do |row|
            attrs = map_attributes(row)
            key = attrs[:unique_key]
            permit = existing[key] || CdotPermit.new(unique_key: key)
            permit.assign_attributes(attrs.except(:unique_key))

            if permit.new_record?
              permit.data_synced_at = sync_time
              permit.save!
              needs_geocoding << permit
              created += 1
            elsif permit.changed?
              address_changed = permit.segment_address_changed?(permit.changes)
              permit.data_synced_at = sync_time
              permit.save!
              needs_geocoding << permit if address_changed || !permit.segment_geocoded?
              updated += 1
            else
              unchanged_keys << key
            end
          end

          if unchanged_keys.any?
            CdotPermit.where(unique_key: unchanged_keys)
                       .update_all(data_synced_at: sync_time)
            unchanged += unchanged_keys.size
          end
        end

        geocode_segments(needs_geocoding)
      end

      break if rows.size < PAGE_SIZE

      next_cursor = rows.last["uniquekey"]
      unless next_cursor.is_a?(String) && next_cursor.match?(VALID_UNIQUE_KEY)
        # Cannot safely advance the keyset cursor; refuse to continue rather
        # than risk re-fetching the same page in a loop or skipping rows.
        raise "Cannot advance pagination cursor: last uniquekey #{next_cursor.inspect} is missing or malformed"
      end
      last_unique_key = next_cursor
    end

    if key_widths.size > 1
      # See the VALID_UNIQUE_KEY note: pagination stays correct, but the
      # cursor order won't match human/numeric expectations once widths
      # diverge. Surface this so we notice the regression instead of
      # debugging "skipped rows" reports that aren't actually skips.
      Rails.logger.warn("[SyncCdotPermits] uniquekey widths drifted across pages: " \
                        "#{key_widths.sort.inspect}. Lexicographic ordering will diverge " \
                        "from numeric ordering; pagination remains self-consistent.")
    end

    message = "SUCCESS: created=#{created} updated=#{updated} unchanged=#{unchanged} " \
              "skipped=#{skipped} (#{pages} pages)"
    Rails.logger.info("[SyncCdotPermits] #{message}")
    message
  rescue => e
    Rails.logger.error("[SyncCdotPermits] Failed after #{pages} pages " \
                       "(created=#{created} updated=#{updated} unchanged=#{unchanged} " \
                       "skipped=#{skipped}): #{e.class}: #{e.message}")
    Sentry.set_context("sync_cdot_permits", {
      pages: pages,
      created: created,
      updated: updated,
      unchanged: unchanged,
      skipped: skipped,
      last_unique_key: last_unique_key,
    })
    raise
  end

  private

  def row_usable?(row)
    return false unless REQUIRED_API_FIELDS.all? { |field| row[field].to_s.strip.present? }
    row["uniquekey"].to_s.match?(VALID_UNIQUE_KEY)
  end

  def fetch_page(last_unique_key)
    uri = build_uri(last_unique_key)
    headers = {}
    token = ENV["CHICAGO_DATA_PORTAL_APP_TOKEN"]
    headers["X-App-Token"] = token if token.present?

    retries = 0
    begin
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                 open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get(uri.request_uri, headers)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise HttpError.new(
          "HTTP #{response.code}: #{response.body.truncate(200)}",
          code: response.code,
          retry_after_seconds: parse_retry_after(response["Retry-After"]),
        )
      end

      JSON.parse(response.body)
    rescue *RETRYABLE_NETWORK_ERRORS, HttpError => e
      raise unless retries < MAX_RETRIES && retryable?(e)

      retries += 1
      delay = retry_delay(e, retries)
      Rails.logger.warn("[SyncCdotPermits] Retry #{retries}/#{MAX_RETRIES} after #{e.class}: #{e.message} (sleeping #{delay}s)")
      sleep(delay)
      retry
    end
  end

  def retryable?(error)
    return true if RETRYABLE_NETWORK_ERRORS.any? { |klass| error.is_a?(klass) }
    return false unless error.is_a?(HttpError)
    error.code.to_s.match?(/\A(5\d\d|429)\z/)
  end

  def retry_delay(error, retries)
    if error.is_a?(HttpError) && error.retry_after_seconds
      [error.retry_after_seconds, MAX_RETRY_AFTER].min
    else
      RETRY_BASE_DELAY * (2**(retries - 1))
    end
  end

  # Per RFC 7231 the Retry-After header may be either an integer number of
  # seconds or an HTTP-date. Returns nil if neither parses.
  def parse_retry_after(value)
    return nil if value.blank?

    if value =~ /\A\s*\d+\s*\z/
      [value.to_i, 0].max
    else
      delta = (Time.httpdate(value) - Time.now).to_i
      delta.positive? ? delta : 0
    end
  rescue ArgumentError
    nil
  end

  def build_uri(last_unique_key)
    start_of_today = Time.current.in_time_zone("America/Chicago")
                          .beginning_of_day
                          .strftime("%Y-%m-%dT%H:%M:%S")

    predicates = [
      "applicationstatus='Open'",
      "applicationexpiredate>='#{start_of_today}'",
      *REQUIRED_API_FIELDS.map { |f| "#{f} IS NOT NULL" },
    ]

    if last_unique_key
      unless last_unique_key.match?(VALID_UNIQUE_KEY)
        raise "Unexpected uniquekey format: #{last_unique_key.inspect}"
      end
      predicates << "uniquekey>'#{last_unique_key}'"
    end

    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(
      "$select" => FIELD_MAP.keys.join(","),
      "$where"  => predicates.join(" AND "),
      "$order"  => "uniquekey",
      "$limit"  => PAGE_SIZE.to_s,
    )
    uri
  end

  def map_attributes(row)
    attrs = {}

    FIELD_MAP.each do |api_field, ar_attr|
      value = row[api_field]
      value = parse_datetime(value) if DATE_FIELDS.include?(ar_attr)
      value = value&.to_i if INTEGER_FIELDS.include?(ar_attr) && value.present?
      attrs[ar_attr] = value
    end

    lat = row["latitude"]
    lng = row["longitude"]
    if lat.present? && lng.present?
      begin
        attrs[:location] = GEO_FACTORY.point(Float(lng), Float(lat))
      rescue ArgumentError
        attrs[:location] = nil
      end
    else
      attrs[:location] = nil
    end

    attrs
  end

  def parse_datetime(value)
    return nil if value.blank?
    Time.zone.parse(value)
  rescue ArgumentError
    nil
  end

  def geocode_segments(permits)
    permits.each_with_index do |permit, i|
      sleep(GEOCODE_THROTTLE_DELAY) if i > 0
      geocode_segment(permit)
    rescue StandardError => e
      Rails.logger.warn(
        "[SyncCdotPermits] Geocode failed for permit #{permit.unique_key}: " \
        "#{e.class}: #{e.message}"
      )
    end
  end

  def geocode_segment(permit)
    addresses = permit.segment_addresses
    return if addresses.compact.empty?

    from_result = geocode_address(addresses[0])
    sleep(GEOCODE_THROTTLE_DELAY) if addresses[1].present?
    to_result = geocode_address(addresses[1])

    fallback = permit_fallback_point(permit)
    from_result ||= fallback
    to_result   ||= fallback
    from_result ||= to_result
    to_result   ||= from_result
    return if from_result.nil?

    permit.update!(
      segment_from_lat: from_result.lat,
      segment_from_lng: from_result.lng,
      segment_to_lat: to_result.lat,
      segment_to_lng: to_result.lng,
    )
  end

  def geocode_address(address)
    return nil if address.nil?
    GeocodeAddress.new(address: address).call
  end

  def permit_fallback_point(permit)
    return nil if permit.latitude.blank? || permit.longitude.blank?
    GeocodeAddress::Result.new(lat: permit.latitude, lng: permit.longitude)
  end

end
