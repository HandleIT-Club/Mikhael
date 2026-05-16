class DropModelConfigs < ActiveRecord::Migration[8.1]
  # Borramos ModelConfig: nunca aportó valor real. Las superficies web y
  # Telegram usaban AssistantContext (system_prompt unificado con reglas
  # anti-alucinación), y solo el CLI/API directa caía a ModelConfig. Mantener
  # un prompt distinto por cada uno de 15 modelos era una invitación al drift.
  #
  # Ahora hay un único Setting global 'assistant_preamble' editable desde
  # /settings — un solo lugar, una sola verdad. Lo concreto del prompt
  # (las reglas y los tools) vive en código (AssistantContext).
  def up
    drop_table :model_configs
  end

  def down
    create_table :model_configs do |t|
      t.string :model_id, null: false
      t.text   :system_prompt, null: false, default: ""
      t.timestamps
    end
    add_index :model_configs, :model_id, unique: true
  end
end
