class AddUniqueIndexOnAlertsEmailAreaWithoutAddress < ActiveRecord::Migration[7.2]
  def change
    add_index :alerts, [ :email, :area_id ],
      unique: true,
      where: "street_address IS NULL",
      name: "index_alerts_on_email_area_without_address"
  end
end
