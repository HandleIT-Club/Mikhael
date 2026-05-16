require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<GROQ_API_KEY>") { ENV["GROQ_API_KEY"] }
  config.default_cassette_options = { record: :new_episodes }
  # Capybara/Cuprite necesita hablar con el server local (Puma) y con Chrome
  # vía CDP. Sin esto, VCR/Webmock bloquean esos requests y los system specs
  # explotan antes de empezar.
  config.ignore_localhost = true
end

WebMock.disable_net_connect!(allow_localhost: true)
