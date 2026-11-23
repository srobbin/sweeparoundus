# Enqueue receipts for one-off campaigns, not recurring sweeping reminders.
class OneOffNotification < ApplicationRecord
  belongs_to :alert

  validates :campaign, :queued_at, presence: true
end
