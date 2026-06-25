class CspReportsController < ApplicationController
  # Browsers POST CSP violation reports without a CSRF token, so CSRF protection
  # would reject every report with a 422 before we ever see it.
  skip_forgery_protection

  # Extension/browser hosts that omit source-file and need host matching.
  # These user-initiated violations are outside our control:
  #   - authenticate.ibotta.com: Ibotta extension iframe blocked by frame-src 'none'.
  #   - translate.google.com: Chrome Translate gen204 beacons reported as img-src.
  KNOWN_EXTENSION_HOSTS = %w[
    authenticate.ibotta.com
    translate.google.com
  ].freeze

  def create
    report = parse_report
    if report && !browser_extension_noise?(report) && !maps_eval_noise?(report)
      Rails.logger.warn("[CSP] #{report.to_json}")
    end
    head :no_content
  end

  private

  def parse_report
    JSON.parse(request.raw_post)
  rescue JSON::ParserError
    nil
  end

  # Browser-injected resources show up either as a source-file or a blocked-uri
  # that begins with one of these schemes.
  EXTENSION_SCHEMES = %w[about moz-extension chrome-extension safari-extension].freeze

  # Extension-injected resources are not actionable; they usually report
  # source-file or blocked-uri as "about" or an extension URI.
  def browser_extension_noise?(report)
    csp = report["csp-report"] || report
    source = csp["source-file"].to_s
    blocked = csp["blocked-uri"].to_s

    source.start_with?(*EXTENSION_SCHEMES) ||
      blocked.start_with?(*EXTENSION_SCHEMES) ||
      KNOWN_EXTENSION_HOSTS.any? { |host| blocked.include?(host) }
  end

  # Google Maps calls eval() internally; its CSP guide documents 'unsafe-eval'
  # as required:
  # https://developers.google.com/maps/documentation/javascript/content-security-policy
  # We intentionally omit it, and Maps/autocomplete still work, so redacted
  # blocked-uri "eval" reports under script-src are harmless noise.
  def maps_eval_noise?(report)
    csp = report["csp-report"] || report
    directive = (csp["effective-directive"] || csp["violated-directive"]).to_s

    csp["blocked-uri"].to_s == "eval" && directive == "script-src"
  end
end
