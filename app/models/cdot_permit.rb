class CdotPermit < ApplicationRecord
  validates :unique_key, presence: true, uniqueness: true

  scope :with_open_status, -> { where(application_status: "Open") }
  scope :starting_after, ->(time) { where("application_start_date > ?", time) }

  # Addresses that anchor the two ends of the permit's construction segment.
  # Returns a 2-element array (from_address, to_address). Either entry may be
  # nil if the underlying fields are missing.
  def segment_addresses
    [segment_address(street_number_from), segment_address(street_number_to)]
  end

  # A short human-readable label for the construction segment, e.g.
  # "3300-3350 N CALIFORNIA AVE". Returns nil if the permit doesn't have
  # enough address fields to form a label.
  def segment_label
    return nil if direction.blank? || street_name.blank?

    range =
      if street_number_from.present? && street_number_to.present? &&
         street_number_from != street_number_to
        "#{street_number_from}-#{street_number_to}"
      else
        street_number_from || street_number_to
      end
    return nil if range.blank?

    [range, direction, street_name, suffix].compact_blank.join(" ")
  end

  # Title-cased street name for prose, e.g. "California Ave". Drops the
  # directional prefix and down-cases CDOT's all-caps. Returns nil if blank.
  def display_street
    return nil if street_name.blank?

    [street_name.titleize, suffix&.titleize.presence].compact.join(" ").presence
  end

  def segment_geocoded?
    segment_from_lat.present? && segment_from_lng.present?
  end

  # Returns a GeocodeAddress::Result so the value can pass through
  # ActiveJob serialization (via GeocodeAddressResultSerializer) when
  # handed to PermitMailer as a mailer param.
  def segment_from
    return nil unless segment_from_lat && segment_from_lng
    GeocodeAddress::Result.new(lat: segment_from_lat, lng: segment_from_lng)
  end

  def segment_to
    return nil unless segment_to_lat && segment_to_lng
    GeocodeAddress::Result.new(lat: segment_to_lat, lng: segment_to_lng)
  end

  SEGMENT_ADDRESS_FIELDS = %w[street_number_from street_number_to direction street_name suffix].freeze

  def segment_address_changed?(previous_changes)
    SEGMENT_ADDRESS_FIELDS.any? { |f| previous_changes.key?(f) }
  end

  def self.ransackable_attributes(_ = nil)
    %w[unique_key application_number application_name application_type
       application_description work_type work_type_description application_status
       application_start_date application_end_date application_expire_date
       application_issued_date detail parking_meter_posting_or_bagging
       street_number_from street_number_to direction street_name suffix
       placement street_closure ward
       x_coordinate y_coordinate latitude longitude
       processed_alert_ids notifications_sent_at
       segment_from_lat segment_from_lng segment_to_lat segment_to_lng
       data_synced_at created_at updated_at]
  end

  private

  def segment_address(number)
    return nil if number.blank? || direction.blank? || street_name.blank?

    parts = [number, direction, street_name, suffix].compact_blank
    "#{parts.join(' ')}, Chicago, IL"
  end

end
