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

  def self.find_by_coordinates(lat, lng)
    point = RGeo::Geos.factory(srid: 0).point(lng.to_f, lat.to_f)
    where(arel_table[:shape].st_contains(point)).first
  end

  def name
    "Ward #{self.ward}, Sweep Area #{self.number}"
  end

  def next_sweep
    today = Time.current.to_date
    sweeps.detect do |sweep|
      (sweep.date_1 && sweep.date_1 >= today) ||
      (sweep.date_2 && sweep.date_2 >= today) ||
      (sweep.date_3 && sweep.date_3 >= today) ||
      (sweep.date_4 && sweep.date_4 >= today)
    end
  end
end
