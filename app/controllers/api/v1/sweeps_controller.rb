module Api
  module V1
    class SweepsController < BaseController
      def index
        lat = params.require(:lat)
        lng = params.require(:lng)

        unless valid_lat?(lat) && valid_lng?(lng)
          return render json: { error: "Invalid coordinates." },
                        status: :unprocessable_entity
        end

        area = Area.find_by_coordinates(lat, lng)

        unless area
          return render json: { error: "No sweep area found for the given coordinates." },
                        status: :not_found
        end

        render json: { area: serialize_area(area) }
      end

      private

      def valid_lat?(value)
        coord = Float(value)
        coord.finite? && coord.between?(-90, 90)
      rescue ArgumentError, TypeError
        false
      end

      def valid_lng?(value)
        coord = Float(value)
        coord.finite? && coord.between?(-180, 180)
      rescue ArgumentError, TypeError
        false
      end

      def serialize_area(area)
        sweep = area.next_sweep

        {
          name: area.name,
          shortcode: area.shortcode,
          url: area_url(area),
          next_sweep: sweep ? serialize_sweep(sweep) : nil
        }
      end

      def serialize_sweep(sweep)
        dates = [sweep.date_1, sweep.date_2, sweep.date_3, sweep.date_4].compact

        {
          dates: dates.map(&:iso8601),
          formatted: dates.map { |d| d.strftime("%B %-d") }.join(" / ")
        }
      end
    end
  end
end
