# Register custom serializers after boot (Rails reads custom_serializers
# only after initialization).
Rails.application.config.after_initialize do
  ActiveJob::Serializers.add_serializers(GeocodeAddressResultSerializer)
end
