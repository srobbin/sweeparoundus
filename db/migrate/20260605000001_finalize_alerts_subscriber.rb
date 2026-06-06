class FinalizeAlertsSubscriber < ActiveRecord::Migration[8.1]
  # Deploy B (contract, destructive) — runs only after Deploy A is verified in
  # production. It makes subscriber_id mandatory, drops the old email-based
  # indexes, and removes the now-unused email/phone columns from alerts.
  #
  # No maintenance mode is required: by the time this ships, every instance runs
  # the new code, which ignores email/phone via Alert.ignored_columns, so
  # dropping those columns is invisible to the running app.
  #
  # Lock-light: index drops run CONCURRENTLY (hence disable_ddl_transaction!).
  # Removing a column is a metadata-only change in Postgres (a brief lock, no
  # table rewrite), and the table is small enough that the change_column_null
  # scan is negligible.
  disable_ddl_transaction!

  # Throwaway models scoped to the tables so the data steps bypass app-level
  # validations/callbacks (notably the MX check) and can touch the email column
  # that the real Alert hides via ignored_columns.
  class MigrationAlert < ActiveRecord::Base
    self.table_name = "alerts"
  end

  class MigrationSubscriber < ActiveRecord::Base
    self.table_name = "subscribers"
  end

  def up
    # Cheap guard: Deploy A ran under web maintenance mode, so no straggler
    # subscriber_id IS NULL rows can exist. Assert it rather than letting
    # change_column_null fail mid-way if Deploy A was ever run without it.
    orphan_count = MigrationAlert.where(subscriber_id: nil).count
    if orphan_count.positive?
      raise "Found #{orphan_count} alert(s) with a NULL subscriber_id — " \
            "backfill them before finalizing (see BackfillSubscribersForAlerts)."
    end

    change_column_null :alerts, :subscriber_id, false

    remove_index :alerts, name: "index_alerts_on_email", algorithm: :concurrently, if_exists: true
    remove_index :alerts, name: "index_alerts_on_subscription_uniqueness", algorithm: :concurrently, if_exists: true
    remove_index :alerts, name: "index_alerts_on_email_area_without_address", algorithm: :concurrently, if_exists: true

    remove_column :alerts, :email, :string
    remove_column :alerts, :phone, :string
  end

  def down
    # Recoverable: email still lives on subscribers, so we re-add the columns,
    # reconstruct alerts.email from the owning subscriber, and rebuild the old
    # email indexes. phone is gone for good (zero values in prod), so it comes
    # back empty.
    add_column :alerts, :email, :string
    add_column :alerts, :phone, :string

    # Reconstruct email from the owning subscriber before rebuilding the unique
    # email indexes (they'd reject NULLs/dupes otherwise). One UPDATE per
    # subscriber, mirroring the backfill migration's find_each/update_all style.
    MigrationSubscriber.find_each do |subscriber|
      MigrationAlert.where(subscriber_id: subscriber.id).update_all(email: subscriber.email)
    end

    add_index :alerts, :email,
      algorithm: :concurrently,
      name: "index_alerts_on_email"

    add_index :alerts, [ :email, :street_address ],
      unique: true,
      algorithm: :concurrently,
      name: "index_alerts_on_subscription_uniqueness"

    add_index :alerts, [ :email, :area_id ],
      unique: true,
      where: "street_address IS NULL",
      algorithm: :concurrently,
      name: "index_alerts_on_email_area_without_address"

    change_column_null :alerts, :subscriber_id, true
  end
end
