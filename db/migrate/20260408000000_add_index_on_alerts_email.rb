class AddIndexOnAlertsEmail < ActiveRecord::Migration[7.2]
  def change
    add_index :alerts, :email
  end
end
