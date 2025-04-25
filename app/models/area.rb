class Area < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  # Future proof, for when the season ends
  has_many :sweeps, -> { where("EXTRACT(YEAR FROM date_1) = ?", Time.current.year).order(:date_1) }
  # nullifies foreign key in alerts table when associated area is deleted
  has_many :alerts, dependent: :nullify

  validates :number, presence: true, uniqueness: { scope: :ward }
  validates :ward, presence: true
  validates :shape, presence: true
  validates :shortcode, presence: true, uniqueness: true

  def name
    "Ward #{self.ward}, Sweep Area #{self.number}"
  end

  def next_sweep
    self.sweeps.where(
      "date_1 >= :today OR date_2 >= :today OR date_3 >= :today OR date_4 >= :today",
      today: Time.current.to_date
    ).order(:date_1).first
  end
end
