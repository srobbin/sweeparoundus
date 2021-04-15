class SetAlertsConfirmedDefault < ActiveRecord::Migration[6.1]
  def change
    change_column_default :alerts, :confirmed, false   
  end
end
