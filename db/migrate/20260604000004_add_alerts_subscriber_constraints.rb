class AddAlertsSubscriberConstraints < ActiveRecord::Migration[8.1]
  # Adds the FK and the new subscriber-scoped unique indexes that replace the
  # email-based ones. Deliberately does NOT set subscriber_id NOT NULL and does
  # NOT drop the old email/phone columns or their indexes — those destructive
  # changes happen in the contract migration (Deploy B), once the expand deploy
  # is verified in production.
  #
  # Everything here runs lock-light so it's safe to apply while the app serves
  # traffic: indexes are built CONCURRENTLY, and the FK is added unvalidated
  # first (a brief lock) then validated in a separate pass (no write lock).
  disable_ddl_transaction!

  def up
    add_index :alerts, [ :subscriber_id, :street_address ],
      unique: true,
      algorithm: :concurrently,
      name: "index_alerts_on_subscriber_and_street_address"

    add_index :alerts, [ :subscriber_id, :area_id ],
      unique: true,
      where: "street_address IS NULL",
      algorithm: :concurrently,
      name: "index_alerts_on_subscriber_and_area_without_address"

    add_foreign_key :alerts, :subscribers, validate: false
    validate_foreign_key :alerts, :subscribers
  end

  def down
    remove_foreign_key :alerts, :subscribers
    remove_index :alerts, name: "index_alerts_on_subscriber_and_area_without_address"
    remove_index :alerts, name: "index_alerts_on_subscriber_and_street_address"
  end
end
