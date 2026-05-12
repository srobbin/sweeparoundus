class AddSegmentCoordinatesToCdotPermits < ActiveRecord::Migration[7.2]
  def change
    add_column :cdot_permits, :segment_from_lat, :decimal, precision: 10, scale: 6
    add_column :cdot_permits, :segment_from_lng, :decimal, precision: 10, scale: 6
    add_column :cdot_permits, :segment_to_lat, :decimal, precision: 10, scale: 6
    add_column :cdot_permits, :segment_to_lng, :decimal, precision: 10, scale: 6
  end
end
