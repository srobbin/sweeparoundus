class Sweep < ApplicationRecord
  belongs_to :area
  has_many :alerts, through: :area
  has_many :confirmed_alerts, -> { confirmed }, through: :area, source: :alerts

  validates :date_1, presence: true, uniqueness: { scope: :area }
end
