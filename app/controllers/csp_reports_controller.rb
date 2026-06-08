class CspReportsController < ApplicationController
  # Browsers POST CSP violation reports without a CSRF token, so CSRF protection
  # would reject every report with a 422 before we ever see it.
  skip_forgery_protection

  # Third-party hosts injected by browser features/extensions (iframes, scripts,
  # beacons, etc.) that carry no source-file, so the source-file heuristic below
  # misses them. These are user-initiated and outside our control:
  #   - authenticate.ibotta.com: the Ibotta cashback extension injects this
  #     iframe, which our frame-src 'none' policy blocks.
  #   - translate.google.com: Chrome's built-in "translate this page" feature
  #     fires gen204 logging beacons (loaded as img-src) when a user translates
  #     the page.
  KNOWN_EXTENSION_HOSTS = %w[
    authenticate.ibotta.com
    translate.google.com
  ].freeze

  def create
    report = parse_report
    if report && !browser_extension_noise?(report)
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

  # Browser extensions (password managers, ad blockers, translators, etc.)
  # inject inline scripts and resources into pages. These show up as CSP
  # violations with a source-file or blocked-uri of "about" or a
  # moz-extension/chrome-extension URI. They're not actionable since they
  # originate outside our code.
  def browser_extension_noise?(report)
    csp = report["csp-report"] || report
    source = csp["source-file"].to_s
    blocked = csp["blocked-uri"].to_s

    source.start_with?(*EXTENSION_SCHEMES) ||
      blocked.start_with?(*EXTENSION_SCHEMES) ||
      KNOWN_EXTENSION_HOSTS.any? { |host| blocked.include?(host) }
  end
end
