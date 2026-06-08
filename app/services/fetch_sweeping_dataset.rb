require "net/http"
require "openssl"
require "json"
require "fileutils"

# Fetches Chicago Data Portal street sweeping datasets: views metadata
# (rowsUpdatedAt + name) and the full CSV/GeoJSON exports. Modeled on the
# Net::HTTP + retry/backoff + X-App-Token pattern in SyncCdotPermits.
#
#   FetchSweepingDataset.metadata("u5ai-3efk")
#   FetchSweepingDataset.download(url, dest: "tmp/candidate.csv")
class FetchSweepingDataset
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 60
  MAX_RETRIES = 5
  RETRY_BASE_DELAY = 2
  MAX_BACKOFF_DELAY = 15
  MAX_RETRY_AFTER = 60

  # 404 specifically means "this dataset id is not published" — for a new-year
  # ID that the City hasn't released yet. The job treats this as an
  # availability signal (skip, alert), distinct from a transient failure.
  NotFound = Class.new(StandardError)

  HttpError = Class.new(StandardError) do
    attr_reader :code, :retry_after_seconds

    def initialize(message, code: nil, retry_after_seconds: nil)
      super(message)
      @code = code
      @retry_after_seconds = retry_after_seconds
    end
  end

  RETRYABLE_NETWORK_ERRORS = [
    Net::OpenTimeout,
    Net::ReadTimeout,
    Errno::ECONNRESET,
    Errno::ETIMEDOUT,
    EOFError,
    SocketError,
    OpenSSL::SSL::SSLError
  ].freeze

  Metadata = Data.define(:id, :name, :rows_updated_at) do
    # Socrata views metadata exposes rowsUpdatedAt as a unix timestamp.
    def self.from_json(id, json)
      raw = json["rowsUpdatedAt"]
      new(id: id, name: json["name"], rows_updated_at: raw && Time.zone.at(raw.to_i))
    end
  end

  class << self
    def metadata(id)
      Metadata.from_json(id, JSON.parse(new.get(SweepingDatasets.metadata_url(id))))
    end

    # Downloads an export endpoint to `dest`, creating parent dirs. Returns dest.
    def download(url, dest:)
      FileUtils.mkdir_p(File.dirname(dest))
      File.binwrite(dest, new.get(url))
      dest
    end
  end

  def get(url)
    with_retries { request(url) }
  end

  private

  # Issues a GET, raising typed errors for non-success responses, and returns
  # the response body.
  def request(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    headers = {}
    token = ENV["CHICAGO_DATA_PORTAL_APP_TOKEN"]
    headers["X-App-Token"] = token if token.present?

    response = http.start { http.get(uri.request_uri, headers) }

    case response
    when Net::HTTPSuccess
      response.body
    when Net::HTTPNotFound
      raise NotFound, "HTTP 404 for #{uri.host}#{uri.path}"
    else
      raise HttpError.new(
        "HTTP #{response.code} for #{uri.host}#{uri.path}",
        code: response.code,
        retry_after_seconds: parse_retry_after(response["Retry-After"])
      )
    end
  end

  def with_retries
    retries = 0
    begin
      yield
    rescue *RETRYABLE_NETWORK_ERRORS, HttpError => e
      raise unless retries < MAX_RETRIES && retryable?(e)

      retries += 1
      delay = retry_delay(e, retries)
      Rails.logger.warn("[FetchSweepingDataset] Retry #{retries}/#{MAX_RETRIES} after #{e.class}: #{e.message} (sleeping #{delay}s)")
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
      [ error.retry_after_seconds, MAX_RETRY_AFTER ].min
    else
      base = [ RETRY_BASE_DELAY * (2**(retries - 1)), MAX_BACKOFF_DELAY ].min
      base + rand * RETRY_BASE_DELAY
    end
  end

  def parse_retry_after(value)
    return nil if value.blank?

    if value =~ /\A\s*\d+\s*\z/
      [ value.to_i, 0 ].max
    else
      delta = (Time.httpdate(value) - Time.now).to_i
      delta.positive? ? delta : 0
    end
  rescue ArgumentError
    nil
  end
end
