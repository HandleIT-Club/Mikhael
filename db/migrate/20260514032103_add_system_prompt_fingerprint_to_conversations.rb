class AddSystemPromptFingerprintToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :system_prompt_fingerprint, :string
  end
end
