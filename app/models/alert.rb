class Alert < ApplicationRecord
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  belongs_to :area, optional: true

  scope :email, -> { where.not(email: nil) }
  scope :phone, -> { where.not(phone: nil) }

  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX }, unless: -> { self.phone.present? }
  validate :email_or_phone

  scope :confirmed, -> { where(confirmed: true) }
  scope :unconfirmed, -> { where(confirmed: false) }
  scope :with_street_address, -> { where.not(street_address: nil) }
  scope :without_street_address, -> { where(street_address: nil) }
  scope :with_coords, -> { where.not(lat: nil, lng: nil) }
  scope :without_coords, -> { where(lat: nil, lng: nil) }

  def self.ransackable_attributes(auth_object = nil)
    %w[area_id confirmed email phone street_address updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[area]
  end

  private

  def email_or_phone
    return if self.email.present? || self.phone.present?

    errors.add(:base, "You must specify either an email or phone number.")
  end
end
