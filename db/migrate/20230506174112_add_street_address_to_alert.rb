class AddStreetAddressToAlert < ActiveRecord::Migration[6.1]
  def change
    add_column :alerts, :street_address, :string, if_not_exists: true
  end
end
