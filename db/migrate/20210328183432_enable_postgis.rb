class EnablePostgis < ActiveRecord::Migration[6.1]
  def change
    execute "CREATE EXTENSION IF NOT EXISTS postgis;"
  end
end
