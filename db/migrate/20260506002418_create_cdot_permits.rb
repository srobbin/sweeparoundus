class CreateCdotPermits < ActiveRecord::Migration[7.2]
  def change
    create_table :cdot_permits, id: :uuid do |t|
      t.string   :unique_key, null: false
      t.string   :application_number
      t.string   :application_name
      t.string   :application_type
      t.string   :application_description
      t.string   :work_type
      t.string   :work_type_description
      t.string   :application_status
      t.datetime :application_start_date
      t.datetime :application_end_date
      t.datetime :application_expire_date
      t.datetime :application_issued_date

      t.text     :detail
      t.string   :parking_meter_posting_or_bagging

      t.integer  :street_number_from
      t.integer  :street_number_to
      t.string   :direction
      t.string   :street_name
      t.string   :suffix
      t.text     :placement
      t.string   :street_closure
      t.integer  :ward

      t.decimal  :x_coordinate, precision: 12, scale: 4
      t.decimal  :y_coordinate, precision: 12, scale: 4
      t.decimal  :latitude,  precision: 10, scale: 6
      t.decimal  :longitude, precision: 10, scale: 6
      t.st_point :location, geographic: true

      t.datetime :data_synced_at
      t.timestamps
    end

    add_index :cdot_permits, :unique_key, unique: true
    add_index :cdot_permits, :application_number
    add_index :cdot_permits, :application_status
    add_index :cdot_permits, :application_start_date
    add_index :cdot_permits, :ward
    add_index :cdot_permits, :parking_meter_posting_or_bagging, name: "index_cdot_permits_on_parking_meter"
    add_index :cdot_permits, :application_expire_date
    add_index :cdot_permits, :data_synced_at
    add_index :cdot_permits, :location, using: :gist
  end
end
