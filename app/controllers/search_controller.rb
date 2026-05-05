class SearchController < ApplicationController
  def index
    unless params[:lat].present? && params[:lng].present?
      flash[:error] = "Please enter an address to search."
      return redirect_to root_path
    end

    @area = Area.find_by_coordinates(params[:lat], params[:lng])

    if @area
      session[:search_lat] = params[:lat].to_f
      session[:search_lng] = params[:lng].to_f
      session[:search_area_id] = @area.id
      session[:street_address] = params[:address]
      session[:search_set_at] = Time.current.to_i
      session[:is_save_street_address_checked] = true
      redirect_to @area
    else
      flash[:error] = "Sorry, we could not find the sweep area associated with your address."
      redirect_to root_path
    end
  end
end
