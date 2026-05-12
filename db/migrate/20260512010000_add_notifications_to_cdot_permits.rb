class AddNotificationsToCdotPermits < ActiveRecord::Migration[7.2]
  def change
    add_column :cdot_permits, :notifications_sent, :jsonb, default: []
    add_column :cdot_permits, :notifications_sent_at, :datetime
    add_index :cdot_permits, :notifications_sent_at
  end
end
