class Alert < ApplicationRecord
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  GEO_FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)

  belongs_to :area, optional: true

  before_save :update_location_from_coords, if: -> { lat_changed? || lng_changed? }

  scope :email, -> { where.not(email: nil) }
  scope :phone, -> { where.not(phone: nil) }

  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX }, unless: -> { self.phone.present? }
  validates :email, uniqueness: { scope: :street_address }, if: -> { email.present? && street_address.present? }
  validate :email_or_phone

  scope :confirmed, -> { where(confirmed: true) }
  scope :unconfirmed, -> { where(confirmed: false) }
  scope :with_street_address, -> { where.not(street_address: nil) }
  scope :without_street_address, -> { where(street_address: nil) }
  scope :with_coords, -> { where.not(lat: nil).where.not(lng: nil) }
  scope :without_coords, -> { where(lat: nil, lng: nil) }
  scope :with_location, -> { where.not(location: nil) }
  scope :permit_notifications_enabled, -> { where(permit_notifications: true) }

  def self.ransackable_attributes(auth_object = nil)
    %w[area_id confirmed email phone street_address updated_at lat lng]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[area]
  end

  private

  def email_or_phone
    return if self.email.present? || self.phone.present?

    errors.add(:base, "You must specify either an email or phone number.")
  end

  def update_location_from_coords
    if lat.present? && lng.present?
      self.location = GEO_FACTORY.point(lng.to_f, lat.to_f)
    else
      self.location = nil
    end
  end
end
