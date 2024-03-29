class AllowNullAreaIdInAlert < ActiveRecord::Migration[7.1]
  def change
    change_column_null :alerts, :area_id, true
  end
end
