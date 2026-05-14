class CreateModelConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :model_configs do |t|
      t.string :model_id, null: false
      t.text :system_prompt, null: false, default: ""

      t.timestamps
    end
    add_index :model_configs, :model_id, unique: true
  end
end
