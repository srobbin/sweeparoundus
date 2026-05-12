class RegeocodeAlertJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(alert_id)
    alert = Alert.find_by(id: alert_id)
    return if alert.nil?

    result = GeocodeAddress.new(address: alert.street_address).call
    return if result.nil?

    area = Area.find_by_coordinates(result.lat, result.lng)

    attrs = { lat: result.lat, lng: result.lng }
    attrs[:area] = area if area
    alert.update!(attrs)
  end
end
