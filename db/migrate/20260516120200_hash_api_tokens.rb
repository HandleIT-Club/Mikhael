class HashApiTokens < ActiveRecord::Migration[8.1]
  # Migra api_token de plain hex a HMAC-SHA256 digest. Conserva los tokens
  # existentes (HMAC es determinístico): los users que tengan el plain en su
  # .env siguen autenticando sin regenerar nada, porque HMAC(plain) == digest.
  #
  # Después de esto, la columna api_token plain desaparece — ya no la
  # necesitamos para nada.
  def up
    add_column :users, :api_token_digest, :string

    # Backfill: HMAC con el secret base. SecureRandom para la sal de los
    # plain ya garantizaba 256 bits — el HMAC mantiene esa entropía.
    User.reset_column_information
    secret = Rails.application.secret_key_base
    User.find_each do |user|
      next if user.attributes["api_token"].blank?
      digest = OpenSSL::HMAC.hexdigest("SHA256", secret, user.attributes["api_token"])
      user.update_columns(api_token_digest: digest)
    end

    change_column_null :users, :api_token_digest, false
    add_index :users, :api_token_digest, unique: true

    remove_index  :users, :api_token
    remove_column :users, :api_token, :string
  end

  def down
    add_column :users, :api_token, :string
    # No podemos invertir el HMAC. Si bajás esta migration, los users tienen
    # que regenerar tokens manualmente. Generamos plain nuevos para no romper.
    User.reset_column_information
    User.find_each do |user|
      user.update_columns(api_token: SecureRandom.hex(32))
    end
    change_column_null :users, :api_token, false
    add_index :users, :api_token, unique: true

    remove_index  :users, :api_token_digest
    remove_column :users, :api_token_digest, :string
  end
end
