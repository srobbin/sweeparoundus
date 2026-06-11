class ErrorsController < ApplicationController
  # Reuses the friendly, on-brand page (logo + address search) so visitors who
  # hit a mistyped/expired/unrouted URL can find their sweep area.
  def not_found
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found }
      format.any { head :not_found }
    end
  end

  def unprocessable_entity
    render_static_page("422", 422)
  end

  def internal_server_error
    render_static_page("500", 500)
  end

  private

  # 422/500 keep their existing static `public/*.html` pages unchanged.
  def render_static_page(name, status)
    respond_to do |format|
      format.html { render file: Rails.public_path.join("#{name}.html"), layout: false, status: status }
      format.any { head status }
    end
  end
end
