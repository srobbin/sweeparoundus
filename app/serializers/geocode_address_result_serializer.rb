# Lets ActiveJob serialize/deserialize GeocodeAddress::Result (e.g. when
# passed as a mailer param). Only lat and lng are persisted.
class GeocodeAddressResultSerializer < ActiveJob::Serializers::ObjectSerializer
  def serialize(result)
    super("lat" => result.lat, "lng" => result.lng)
  end

  def deserialize(hash)
    GeocodeAddress::Result.new(lat: hash["lat"], lng: hash["lng"])
  end

  private

  def klass
    GeocodeAddress::Result
  end
end
