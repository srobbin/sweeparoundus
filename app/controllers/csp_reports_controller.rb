class CspReportsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

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

  # Browser extensions (password managers, ad blockers, translators, etc.)
  # inject inline scripts and resources into pages. These show up as CSP
  # violations with source-file "about" or a moz-extension/chrome-extension
  # URI. They're not actionable since they originate outside our code.
  def browser_extension_noise?(report)
    csp = report["csp-report"] || report
    source = csp["source-file"].to_s

    source.start_with?("about", "moz-extension", "chrome-extension", "safari-extension")
  end
end
