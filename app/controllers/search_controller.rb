class SearchController < ApplicationController
  def index
    # Client lat/lng only proves the user picked an autocomplete suggestion.
    # We re-geocode the address server-side because the Places API coords
    # don't always match the formatted address it returns.
    unless params[:lat].present? && params[:lng].present?
      flash[:error] = "Please enter an address to search."
      return redirect_to root_path
    end

    address = params[:address].to_s.strip
    geocoded = address.present? ? GeocodeAddress.new(address: address).call : nil
    unless geocoded
      flash[:error] = "Sorry, we could not locate that address. Please try a different one."
      return redirect_to root_path
    end

    @area = Area.find_by_coordinates(geocoded.lat, geocoded.lng)

    if @area
      Sentry::Metrics.count("search.area_found", 1, attributes: { area: @area.shortcode })
      session[:search_lat] = geocoded.lat
      session[:search_lng] = geocoded.lng
      session[:search_area_id] = @area.id
      session[:street_address] = address
      session[:search_set_at] = Time.current.to_i
      session[:is_save_street_address_checked] = true
      redirect_to @area
    else
      flash[:error] = "Sorry, we could not find the sweep area associated with your address."
      redirect_to root_path
    end
  end
end
