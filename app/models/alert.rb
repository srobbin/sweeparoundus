class Alert < ApplicationRecord
  GEO_FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)

  # email/phone live on the alerts table until the contract migration drops them.
  # Ignoring them frees the `email` attribute name for the delegate below and
  # stops Rails from selecting columns the app no longer uses.
  self.ignored_columns += %w[email phone]

  belongs_to :area, optional: true
  belongs_to :subscriber

  delegate :email, to: :subscriber, allow_nil: true

  before_save :update_location_from_coords, if: -> { lat_changed? || lng_changed? }

  # Each check is guarded on subscriber_id (and area_id) being present so it only
  # runs with a real value to scope by, matching the DB unique indexes that treat
  # NULLs as distinct. Without the guard, a subscriber-less alert would be
  # compared against every other row where subscriber_id IS NULL and falsely
  # collide.
  validates :street_address, uniqueness: { scope: :subscriber_id }, if: -> { street_address.present? && subscriber_id.present? }
  validates :area_id, uniqueness: { scope: :subscriber_id, conditions: -> { where(street_address: nil) } }, if: -> { street_address.nil? && area_id.present? && subscriber_id.present? }

  scope :confirmed, -> { where(confirmed: true) }
  scope :unconfirmed, -> { where(confirmed: false) }
  scope :with_street_address, -> { where.not(street_address: nil) }
  scope :without_street_address, -> { where(street_address: nil) }
  scope :with_coords, -> { where.not(lat: nil).where.not(lng: nil) }
  scope :without_coords, -> { where(lat: nil, lng: nil) }
  scope :with_location, -> { where.not(location: nil) }
  scope :permit_notifications_enabled, -> { where(permit_notifications: true) }

  def self.ransackable_attributes(auth_object = nil)
    %w[area_id confirmed permit_notifications street_address subscriber_id updated_at lat lng]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[area subscriber]
  end

  private

  def update_location_from_coords
    if lat.present? && lng.present?
      self.location = GEO_FACTORY.point(lng.to_f, lat.to_f)
    else
      self.location = nil
    end
  end
end
