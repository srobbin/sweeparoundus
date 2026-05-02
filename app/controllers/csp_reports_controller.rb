class CspReportsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    report = parse_report
    Rails.logger.warn("[CSP] #{report.to_json}") if report
    head :no_content
  end

  private

  def parse_report
    JSON.parse(request.raw_post)
  rescue JSON::ParserError
    nil
  end
end
