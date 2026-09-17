require "net/http"

class TurnstileVerifier
  VERIFY_URL = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")
  ACTION = "manage-subscriptions"
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3

  def self.configured?
    site_key.present? && secret_key.present?
  end

  def self.site_key
    ENV["TURNSTILE_SITE_KEY"]
  end

  def self.secret_key
    ENV["TURNSTILE_SECRET_KEY"]
  end

  def initialize(token:, remote_ip:, expected_hostname:)
    @token = token
    @remote_ip = remote_ip
    @expected_hostname = expected_hostname
  end

  def call
    return true if !Rails.env.production? && !self.class.configured?
    return false unless self.class.configured?
    return false if token.blank?

    response = Net::HTTP.start(
      VERIFY_URL.host,
      VERIFY_URL.port,
      use_ssl: true,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT
    ) do |http|
      http.post(VERIFY_URL.request_uri, URI.encode_www_form(request_params),
        "Content-Type" => "application/x-www-form-urlencoded")
    end

    response.is_a?(Net::HTTPSuccess) && valid_response?(JSON.parse(response.body))
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
         SocketError, SystemCallError => e
    Rails.logger.warn("[TurnstileVerifier] Verification unavailable: #{e.class}")
    false
  end

  private

  attr_reader :token, :remote_ip, :expected_hostname

  def request_params
    {
      secret: self.class.secret_key,
      response: token,
      remoteip: remote_ip
    }
  end

  def valid_response?(result)
    result.is_a?(Hash) &&
      result["success"] == true &&
      result["action"] == ACTION &&
      result["hostname"].to_s.casecmp?(expected_hostname.to_s)
  end
end
