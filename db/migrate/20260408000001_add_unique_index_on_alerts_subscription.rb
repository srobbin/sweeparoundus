class AddUniqueIndexOnAlertsSubscription < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL.squish
      DELETE FROM alerts
      WHERE id IN (
        SELECT id FROM (
          SELECT id,
            ROW_NUMBER() OVER (
              PARTITION BY email, street_address
              ORDER BY confirmed DESC, created_at ASC
            ) AS rn
          FROM alerts
          WHERE street_address IS NOT NULL
        ) ranked
        WHERE rn > 1
      )
    SQL

    add_index :alerts, [ :email, :street_address ],
      unique: true,
      name: "index_alerts_on_subscription_uniqueness"
  end

  def down
    remove_index :alerts, name: "index_alerts_on_subscription_uniqueness"
  end
end
