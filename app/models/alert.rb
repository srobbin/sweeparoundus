class Alert < ApplicationRecord
  belongs_to :area

  scope :email, -> { where.not(email: nil) }
  scope :phone, -> { where.not(phone: nil) }

  validates :email, email: { mode: :strict, require_fqdn: true }, unless: -> { self.phone.present? }
  validate :email_or_phone

  scope :confirmed, -> { where(confirmed: true) }
  scope :unconfirmed, -> { where(confirmed: false) }

  private

  def email_or_phone
    return if self.email.present? || self.phone.present?

    errors.add(:base, "You must specify either an email or phone number.")
  end
end
