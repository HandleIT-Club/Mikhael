# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class ToolCallParser
  def self.parse(text)
    cleaned = text.to_s.strip.gsub(/\A```(?:json)?\s*|\s*```\z/m, "")
    json    = extract_json_object(cleaned)
    return nil unless json

    data = JSON.parse(json)
    return nil unless data.is_a?(Hash) && data["tool"].is_a?(String)

    data
  rescue JSON::ParserError
    nil
  end

  # Extrae el primer objeto JSON balanceado dentro del texto, ignorando lo que venga después.
  def self.extract_json_object(text)
    start = text.index("{")
    return nil unless start

    depth     = 0
    in_string = false
    escaped   = false

    text[start..].each_char.with_index do |ch, i|
      if in_string
        if escaped
          escaped = false
        elsif ch == "\\"
          escaped = true
        elsif ch == '"'
          in_string = false
        end
      elsif ch == '"'
        in_string = true
      elsif ch == "{"
        depth += 1
      elsif ch == "}"
        depth -= 1
        return text[start, i + 1] if depth.zero?
      end
    end
    nil
  end
end
