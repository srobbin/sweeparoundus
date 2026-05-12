class AddLocationToAlerts < ActiveRecord::Migration[7.2]
  def change
    add_column :alerts, :location, :st_point, geographic: true
    add_index :alerts, :location, using: :gist

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE alerts
          SET location = ST_SetSRID(ST_MakePoint(lng, lat), 4326)
          WHERE lat IS NOT NULL AND lng IS NOT NULL
        SQL
      end
    end
  end
end
