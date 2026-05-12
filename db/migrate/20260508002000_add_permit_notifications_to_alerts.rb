class AddPermitNotificationsToAlerts < ActiveRecord::Migration[7.2]
  def change
    add_column :alerts, :permit_notifications, :boolean, default: true, null: false
  end
end
