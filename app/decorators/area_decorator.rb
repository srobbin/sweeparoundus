class AreaDecorator < ApplicationDecorator
  decorates_association :sweeps

  def map_image
    # Convert the shape to a GMap-friendly query
    path = object.shape[0].exterior_ring.points.map do |point|
      "|#{point.y}, #{point.x}"
    end.join

    # We remember the lat/lng they searched for and show a marker if applicable
    search_point = RGeo::Geos.factory(srid: 0).point(session[:search_lng].to_f, session[:search_lat].to_f)
    marker = object.shape.contains?(search_point) ? "&markers=|#{session[:search_lat]},#{session[:search_lng]}|" : ""

    # Generate the static map image
    url = "https://maps.googleapis.com/maps/api/staticmap?size=600x600#{marker}&path=color:0x00000000|weight:5|fillcolor:0xAA000033#{path}&sensor=false&key=#{ENV["GOOGLE_MAPS_BACKEND_API_KEY"]}"

    # Return an image
    image_tag url, alt: "Sweep area map for #{object.name}"
  end

  def next_sweep
    dates = 1.upto(4).map do |n|
      next unless object.next_sweep.present?
      object.next_sweep.send("date_#{n}").try(:strftime, "%B %-d")
    end.compact.join(" / ")

    dates.present? ? dates : "No sweeps scheduled in the near future."
  end
end
