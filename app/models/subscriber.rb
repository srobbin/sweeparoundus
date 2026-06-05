class Subscriber < ApplicationRecord
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  has_many :alerts, dependent: :destroy

  before_validation :normalize_email

  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX }
  validates :email, uniqueness: { case_sensitive: false }
  validate :email_domain_has_mx_record, on: :create, if: -> { email.present? && errors[:email].empty? }

  def self.ransackable_attributes(auth_object = nil)
    %w[email created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[alerts]
  end

  # Removes a just-created subscriber that ended up with no persisted alerts
  # (e.g. its first alert failed to save), so a failed signup never leaves an
  # orphan subscriber behind. No-op for pre-existing subscribers. Uses
  # `exists?` rather than `alerts.empty?` so an in-memory alert built via
  # `find_or_initialize_by` (and not saved) doesn't mask a childless row.
  def destroy_if_childless
    destroy if previously_new_record? && !alerts.exists?
  end

  private

  def normalize_email
    self.email = email.strip.downcase if email.present?
  end

  def email_domain_has_mx_record
    domain = email.split("@").last
    Resolv::DNS.open do |dns|
      dns.timeouts = 2
      return if dns.getresources(domain, Resolv::DNS::Resource::IN::MX).any?
      return if dns.getresources(domain, Resolv::DNS::Resource::IN::A).any?
    end
    errors.add(:email, "domain does not appear to accept email")
  rescue Resolv::ResolvError, Resolv::ResolvTimeout => e
    Rails.logger.warn("[Subscriber] MX check failed for #{domain}: #{e.class}: #{e.message}")
  end
end
