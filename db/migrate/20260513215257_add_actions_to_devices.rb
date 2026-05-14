class AddActionsToDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :devices, :actions, :text
  end
end
