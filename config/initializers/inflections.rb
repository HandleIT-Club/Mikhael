# Be sure to restart your server when you modify this file.

# Zeitwerk infiere constantes desde nombres de archivo: openai_compatible_client.rb
# → OpenaiCompatibleClient. Pero el código define OpenAiCompatibleClient (con
# AI separado), y SambaNovaClient en sambanova_client.rb. En development
# (eager_load=false) no se nota; en production rompe el boot.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "OpenAi"
  inflect.acronym "SambaNova"
end
