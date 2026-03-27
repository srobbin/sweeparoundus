module Api
  module V1
    class BaseController < ActionController::API
      include Rails.application.routes.url_helpers

      rescue_from ActionController::ParameterMissing do |e|
        render json: { error: "Missing required parameter: #{e.param}" }, status: :unprocessable_entity
      end

      private

      def default_url_options
        { host: request.host, port: request.port }
      end
    end
  end
end
