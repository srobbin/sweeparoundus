class Sweep < ApplicationRecord
  belongs_to :area
  has_many :alerts, through: :area

  validates :date_1, presence: true, uniqueness: { scope: :area }
end
