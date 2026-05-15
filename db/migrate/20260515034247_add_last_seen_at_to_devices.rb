class AddLastSeenAtToDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :devices, :last_seen_at, :datetime
  end
end
