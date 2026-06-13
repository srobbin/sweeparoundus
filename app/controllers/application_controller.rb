class ApplicationController < ActionController::Base
  include NoStoreResponses

  # Unknown/expired slugs (e.g. a bot hitting `/areas/ward-2-r1w445r54ea35w`)
  # raise RecordNotFound. Render an on-brand 404 with a search box instead of
  # the bare static `public/404.html` so real visitors can find their area.
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def render_not_found
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found }
      # Reply text/plain (not the requested format). A bare `head :not_found`
      # mirrors the request format, so a scanner's `.js` probe gets a
      # `text/javascript` empty body, which trips Rails' cross-origin JS forgery
      # check (logs a "Security warning..." + raises InvalidCrossOriginRequest).
      format.any { head :not_found, content_type: "text/plain" }
    end
  end
end
