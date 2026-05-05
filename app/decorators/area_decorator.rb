class AreaDecorator < ApplicationDecorator
  decorates_association :sweeps

  MAX_PATH_CHARS = 12_000

  def map_image(show_marker: false)
    path = cached_map_path
    marker = show_marker ? marker_param : ""

    url = "https://maps.googleapis.com/maps/api/staticmap?size=600x600#{marker}&path=color:0x00000000|weight:5|fillcolor:0xAA000033#{path}&sensor=false&key=#{ENV["GOOGLE_MAPS_FRONTEND_API_KEY"]}"

    image_tag url, alt: "Sweep area map for #{object.name}"
  end

  # Largest tolerance we'll ever try. ~0.001° lng at Chicago latitude is
  # roughly 80m, which is already coarser than any sweep-zone boundary
  # detail; doubling past this can collapse the polygon to nothing.
  MAX_SIMPLIFY_TOLERANCE = 0.001

  def next_sweep
    dates = 1.upto(4).map do |n|
      next unless object.next_sweep.present?
      object.next_sweep.send("date_#{n}").try(:strftime, "%B %-d")
    end.compact.join(" / ")

    dates.present? ? dates : "No sweeps scheduled in the near future."
  end

  private

  def marker_param
    return "" unless session[:search_lat].present? && session[:search_lng].present?
    "&markers=|#{session[:search_lat]},#{session[:search_lng]}|"
  end

  def cached_map_path
    Rails.cache.fetch("area_map_path:#{object.id}:#{object.updated_at.to_i}", expires_in: 30.days) do
      poly = simplified_shape
      poly ? encode_path(poly.exterior_ring.points) : ""
    end
  end

  # Google Static Maps URLs are limited to 16,384 characters. The non-path
  # overhead is ~200 chars, so we budget MAX_PATH_CHARS for the encoded
  # polygon and simplify until it fits, capping the tolerance so we don't
  # collapse the polygon to nothing. As a last resort, fall back to the
  # original (un-simplified) polygon and let `encode_path` truncate the
  # point list with even spacing to stay under budget. Returns nil if no
  # usable polygon can be produced from `object.shape` at all (e.g. an
  # empty MultiPolygon), in which case the caller should render no path.
  def simplified_shape
    tolerance = 0.00005
    while tolerance <= MAX_SIMPLIFY_TOLERANCE
      poly = polygon_from(object.shape.simplify(tolerance))
      return poly if poly && encode_path(poly.exterior_ring.points).length <= MAX_PATH_CHARS

      tolerance *= 2
    end

    Rails.logger.warn("[AreaDecorator] Could not simplify polygon under #{MAX_PATH_CHARS} chars for area #{object.id}; truncating point list")
    polygon_from(object.shape)
  end

  def encode_path(points)
    encoded = points.map { |pt| "|#{pt.y},#{pt.x}" }
    path = encoded.join
    return path if path.length <= MAX_PATH_CHARS

    avg_segment = path.length.to_f / encoded.size
    max_points = (MAX_PATH_CHARS / avg_segment).floor
    max_points = [max_points, 4].max
    step = (encoded.size - 1).to_f / (max_points - 1)
    (0...max_points).map { |i| encoded[(i * step).round] }.join
  end

  def polygon_from(geometry)
    return nil if geometry.nil?

    polygon =
      if geometry.respond_to?(:exterior_ring)
        geometry
      elsif geometry.respond_to?(:num_geometries) && geometry.num_geometries.positive?
        geometry[0]
      end

    return nil unless polygon.respond_to?(:exterior_ring)
    return nil if polygon.exterior_ring.points.empty?

    polygon
  end
end
