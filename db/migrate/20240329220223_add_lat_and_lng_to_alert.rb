class AddLatAndLngToAlert < ActiveRecord::Migration[7.1]
  def change
    add_column :alerts, :lat, :decimal, precision: 10, scale: 6
    add_column :alerts, :lng, :decimal, precision: 10, scale: 6
  end
end
