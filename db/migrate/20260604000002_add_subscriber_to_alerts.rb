class AddSubscriberToAlerts < ActiveRecord::Migration[8.1]
  # Nullable on purpose: during the expand deploy, old instances still running
  # the pre-refactor code must be able to insert alerts without a subscriber_id.
  # The NOT NULL constraint is added later, in the contract migration.
  #
  # Just the column here — adding a nullable column with no default is a
  # metadata-only change (a brief lock, no table rewrite), so this stays an
  # ordinary transactional migration. The supporting index is added separately
  # and CONCURRENTLY in AddAlertsSubscriberConstraints, where the composite
  # unique index on (subscriber_id, street_address) already covers subscriber_id
  # lookups and the foreign key — so no standalone subscriber_id index is needed.
  def change
    add_column :alerts, :subscriber_id, :uuid
  end
end
