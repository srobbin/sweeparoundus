module SearchContext
  extend ActiveSupport::Concern

  # Past this window, treat the session as if no search happened.
  SEARCH_CONTEXT_TTL = 1.day

  private

  # Sets instance variables for the alerts subscribe form. Requires
  # `@area` to be set. Used by both the area show page and the
  # create.turbo_stream response.
  def set_search_context
    @viewing_adjacent_area = false
    @searched_address = nil
    @adjacent_to_address = nil
    @show_search_marker = false

    return unless search_session_present?

    if searched_in_this_area?
      @searched_address = session[:street_address]
      @show_search_marker = true
    elsif params[:from_neighbor].present?
      @viewing_adjacent_area = true
      @adjacent_to_address = session[:street_address]
      @show_search_marker = true
    end
  end

  # Separated from `set_search_context` because it issues a PostGIS
  # query and up to MAX_NEIGHBORS Google Geocoding requests.
  def load_neighbors
    @neighbors = []
    return unless search_session_present? && searched_in_this_area?

    @neighbors = FindAdjacentSweepAreas.new(
      area: @area,
      lat: session[:search_lat],
      lng: session[:search_lng]
    ).call
  rescue StandardError => e
    Rails.logger.error("[SearchContext] Failed to load neighbors for area #{@area.id}: #{e.class}: #{e.message}")
    Sentry.capture_exception(e, contexts: { search_context: { area_id: @area.id } })
    @neighbors = []
  end

  def search_session_present?
    session[:search_area_id].present? &&
      session[:search_lat].present? &&
      session[:search_lng].present? &&
      search_session_fresh?
  end

  def search_session_fresh?
    set_at = session[:search_set_at]
    return false if set_at.blank?

    Time.current.to_i - set_at.to_i <= SEARCH_CONTEXT_TTL.to_i
  end

  # Areas use UUID primary keys — calling `.to_i` on a UUID would
  # silently parse only the leading digits and never match.
  def searched_in_this_area?
    session[:search_area_id].to_s == @area.id.to_s
  end
end
