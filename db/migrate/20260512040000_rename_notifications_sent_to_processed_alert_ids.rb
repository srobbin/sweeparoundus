class RenameNotificationsSentToProcessedAlertIds < ActiveRecord::Migration[7.2]
  def change
    rename_column :cdot_permits, :notifications_sent, :processed_alert_ids
  end
end
