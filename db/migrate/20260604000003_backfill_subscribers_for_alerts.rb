class BackfillSubscribersForAlerts < ActiveRecord::Migration[8.1]
  # Throwaway models scoped to the tables so the data migration can see the
  # `email` column that the real Alert hides via ignored_columns, and so no
  # app-level validations (notably the MX/DNS check) or callbacks run here.
  class MigrationAlert < ActiveRecord::Base
    self.table_name = "alerts"
  end

  class MigrationSubscriber < ActiveRecord::Base
    self.table_name = "subscribers"
  end

  # No pure-AR equivalent for the normalized-email expression, so it stays Arel.
  NORMALIZED_EMAIL = Arel.sql("lower(btrim(email))").freeze

  def up
    # 1. Remove phone-only (NULL email) alerts. The pre-migration audit found 0.
    null_email_count = MigrationAlert.where(email: nil).count
    say "Deleting #{null_email_count} alert(s) with a NULL email (phone-only)"
    MigrationAlert.where(email: nil).delete_all

    # 2. Refuse to proceed if any case/whitespace variants would collide under
    #    the new subscriber-scoped unique indexes. The audit found none and the
    #    controller normalizes on create, so this should never fire — but it
    #    fails loud here rather than blowing up at index creation if data drifted.
    assert_no_collisions!

    # 3. One subscriber per distinct normalized email, stamped with the earliest
    #    alert's created_at. insert_all skips validations and callbacks.
    now = Time.current
    rows = MigrationAlert.group(NORMALIZED_EMAIL).minimum(:created_at).map do |email, created_at|
      { email: email, created_at: created_at, updated_at: now }
    end
    MigrationSubscriber.insert_all(rows) if rows.any?

    # 4. Link each alert to its subscriber by normalized email.
    MigrationSubscriber.find_each do |subscriber|
      MigrationAlert.where("lower(btrim(email)) = ?", subscriber.email)
                    .update_all(subscriber_id: subscriber.id)
    end

    orphan_count = MigrationAlert.where(subscriber_id: nil).count
    raise "Backfill left #{orphan_count} alert(s) without a subscriber_id" if orphan_count.positive?
  end

  def down
    MigrationAlert.update_all(subscriber_id: nil)
    MigrationSubscriber.delete_all
  end

  private

  def assert_no_collisions!
    address_collisions = MigrationAlert.where.not(street_address: nil)
                                       .group(NORMALIZED_EMAIL, :street_address)
                                       .having(Arel.sql("COUNT(*) > 1"))
                                       .count.size

    areawide_collisions = MigrationAlert.where(street_address: nil)
                                        .group(NORMALIZED_EMAIL, :area_id)
                                        .having(Arel.sql("COUNT(*) > 1"))
                                        .count.size

    total = address_collisions + areawide_collisions
    return if total.zero?

    raise "Found #{total} normalized-email collision group(s) " \
          "(#{address_collisions} address, #{areawide_collisions} area-wide). " \
          "Dedupe before backfilling — see the plan's audit queries."
  end
end
