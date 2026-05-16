class NormalizeDeviceActionsToJson < ActiveRecord::Migration[8.1]
  # Migra Device#actions de CSV string ("open_valve, close_valve") a JSON
  # array (["open_valve", "close_valve"]). El CSV rompe si una acción tiene
  # coma en el nombre y es frágil para validar / serializar a la API.
  #
  # La columna sigue siendo text (SQLite no tiene tipo json nativo, igual
  # serialize hace el cast en el modelo).
  def up
    # Backfill: leemos cada registro existente, parseamos como CSV, escribimos
    # como JSON. UPDATE directo sin tocar callbacks/validations.
    execute_in_batches do |id, raw|
      next if raw.blank?

      # Si ya parece JSON array, lo dejamos.
      begin
        parsed = JSON.parse(raw)
        next if parsed.is_a?(Array)
      rescue JSON::ParserError
        # no era JSON — caemos al split CSV
      end

      array = raw.to_s.split(",").map(&:strip).reject(&:empty?)
      update("UPDATE devices SET actions = #{connection.quote(array.to_json)} WHERE id = #{id}")
    end
  end

  def down
    execute_in_batches do |id, raw|
      next if raw.blank?
      array = begin
                JSON.parse(raw)
              rescue JSON::ParserError
                next
              end
      next unless array.is_a?(Array)
      csv = array.join(", ")
      update("UPDATE devices SET actions = #{connection.quote(csv)} WHERE id = #{id}")
    end
  end

  private

  def execute_in_batches
    select_rows("SELECT id, actions FROM devices").each do |id, raw|
      yield(id, raw)
    end
  end
end
