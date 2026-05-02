class ApplicationController < ActionController::Base
  before_action :set_security_headers

  private

  def set_security_headers
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
  end
end
