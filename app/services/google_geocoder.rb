require "net/http"

# Abstract base for the Google Maps Geocoding API. Handles HTTP requests,
# caching, retries with exponential back-off, and error reporting.
# Subclasses (GeocodeAddress, ReverseGeocodeAddress) only need to define
# the methods listed below.
#
# Subclass contract (all private):
#   query_params        -> Hash of query-string params (key= is added automatically)
#   cache_key           -> String unique to this query
#   parse_success(json) -> parsed value to return when status is "OK", or nil
#   blank_query?        -> return true to skip work entirely (default: false)
#   log_identifier      -> short label for log messages (e.g. an address string)
#
# Public interface:
#   #call         -> the parsed value, or nil on any failure
#   #error_reason -> nil on success; a short string describing the failure
class GoogleGeocoder
  CACHE_TTL = 30.days
  NIL_CACHE_TTL = 1.day
  ERROR_CACHE_TTL = 1.hour
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 2
  MAX_RETRIES = 3
  RETRY_BASE_DELAY = 2

  GEOCODING_ENDPOINT = "https://maps.googleapis.com/maps/api/geocode/json".freeze

  RETRYABLE_API_STATUSES = %w[OVER_QUERY_LIMIT UNKNOWN_ERROR].freeze

  attr_reader :error_reason

  def call
    @error_reason = nil
    return nil if blank_query?
    return nil if api_key.blank?

    cached = Rails.cache.read(cache_key)
    if cached.is_a?(Hash) && cached.key?(:value)
      @error_reason = cached[:error_reason]
      return cached[:value]
    end

    value, transient = fetch_with_retries
    ttl = if value
            CACHE_TTL
          elsif transient
            ERROR_CACHE_TTL
          else
            NIL_CACHE_TTL
          end
    Rails.cache.write(cache_key, { value: value, error_reason: @error_reason }, expires_in: ttl)
    value
  end

  private

  # ----- Subclass overrides --------------------------------------------------

  def query_params
    raise NotImplementedError, "#{self.class} must implement #query_params"
  end

  def cache_key
    raise NotImplementedError, "#{self.class} must implement #cache_key"
  end

  def parse_success(_json)
    raise NotImplementedError, "#{self.class} must implement #parse_success"
  end

  def blank_query?
    false
  end

  def log_identifier
    nil
  end

  # ----- Shared implementation ----------------------------------------------

  TRANSIENT_NETWORK_ERRORS = [
    Net::OpenTimeout,
    Net::ReadTimeout,
    Errno::ECONNRESET,
  ].freeze

  def fetch_with_retries
    retries = 0
    begin
      fetch_once
    rescue *TRANSIENT_NETWORK_ERRORS, TransientHttpError, TransientApiError => e
      if retries < MAX_RETRIES
        retries += 1
        sleep(RETRY_BASE_DELAY * (2**(retries - 1)))
        retry
      end
      @error_reason = exhausted_retry_reason(e)
      log_warn("#{e.class}: #{e.message} (after #{retries} retries)")
      Sentry.capture_exception(e, level: :warning, contexts: {
        google_geocoder: { class: self.class.name, identifier: log_identifier, retries: retries },
      })
      [nil, true]
    rescue StandardError => e
      @error_reason = "http_error: #{e.message}"
      log_warn("#{e.class}: #{e.message}")
      Sentry.capture_exception(e, level: :warning, contexts: {
        google_geocoder: { class: self.class.name, identifier: log_identifier },
      })
      [nil, true]
    end
  end

  def exhausted_retry_reason(error)
    case error
    when TransientApiError  then error.message
    when TransientHttpError then "http_status: #{error.message.sub(/\AHTTP /, '')}"
    else                         "http_error: #{error.message}"
    end
  end

  def fetch_once
    response = http_get(api_key)

    unless response.is_a?(Net::HTTPSuccess)
      if retryable_http?(response.code)
        raise TransientHttpError, "HTTP #{response.code}"
      end
      @error_reason = "http_status: #{response.code}"
      log_warn("HTTP #{response.code}")
      Sentry.capture_message("[#{self.class.name}] HTTP #{response.code}", level: :warning,
        contexts: { google_geocoder: { identifier: log_identifier } })
      return [nil, true]
    end

    json = JSON.parse(response.body)
    interpret_json(json)
  end

  def api_key
    ENV["GOOGLE_MAPS_BACKEND_API_KEY"]
  end

  def http_get(api_key)
    uri = URI(GEOCODING_ENDPOINT)
    uri.query = URI.encode_www_form(query_params.merge(key: api_key))
    Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                    open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.get(uri.request_uri)
    end
  end

  def interpret_json(json)
    case json["status"]
    when "OK"
      parsed = parse_success(json)
      if parsed
        [parsed, false]
      else
        @error_reason = "geocode_status: OK_NO_USABLE_RESULT"
        [nil, false]
      end
    when "ZERO_RESULTS"
      @error_reason = "geocode_status: ZERO_RESULTS"
      [nil, false]
    when *RETRYABLE_API_STATUSES
      raise TransientApiError, "geocode_status: #{json["status"]}"
    else
      @error_reason = "geocode_status: #{json["status"]}"
      log_warn("Unexpected status=#{json["status"]}")
      Sentry.capture_message("[#{self.class.name}] Unexpected status=#{json["status"]}", level: :warning,
        contexts: { google_geocoder: { identifier: log_identifier, status: json["status"] } })
      [nil, true]
    end
  end

  def retryable_http?(code)
    code.to_s =~ /\A(5\d\d|429)\z/
  end

  def log_warn(message)
    Rails.logger.warn("[#{self.class.name}] #{message}#{log_identifier ? " for #{log_identifier}" : ""}")
  end

  TransientHttpError = Class.new(StandardError)
  TransientApiError  = Class.new(StandardError)
end
