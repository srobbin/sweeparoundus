class SearchController < ApplicationController
  def index
    point = RGeo::Geos.factory(srid: 0).point(params[:lng].to_f, params[:lat].to_f)
    areas = Area.arel_table
    @area =  Area.where(areas[:shape].st_contains(point)).first

    session[:search_lat] = params[:lat]
    session[:search_lng] = params[:lng]

    if @area
      redirect_to @area
    else
      flash[:error] = "Sorry, we would not find the sweep area associated with your address."
      redirect_to root_path
    end
  end
end
