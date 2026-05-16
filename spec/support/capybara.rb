# Cuprite + Capybara setup para system specs.
# Cuprite habla CDP directo con Chrome — no necesitamos Selenium ni
# chromedriver. Si no hay Chrome en el PATH, los specs system se saltan.

require "capybara/rspec"
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size:    [ 1280, 800 ],
    browser_options: { "no-sandbox" => nil },
    process_timeout: 20,
    inspector:      ENV["CUPRITE_INSPECTOR"] == "true",
    headless:       ENV["HEADLESS"] != "false"
  )
end

Capybara.javascript_driver = :cuprite
Capybara.default_driver    = :cuprite
Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  config.before(:each, type: :system) { driven_by :cuprite }
end
