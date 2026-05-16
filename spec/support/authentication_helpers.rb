# Helpers de login para specs.
#
# Para request specs: sign_in_as(user) escribe en session[:user_id].
# Para system specs (Capybara): sign_in_through_form(user) llena el form de login.

module AuthenticationHelpers
  # Request spec helper. ActionDispatch::IntegrationTest expone session via
  # cookies, así que llamamos al SessionsController real para crear la sesión.
  def sign_in_as(user, password: "supersecret123456")
    post session_path, params: { email: user.email, password: password }
  end
end

module SystemAuthenticationHelpers
  def sign_in_through_form(user, password: "supersecret123456")
    visit new_session_path
    fill_in "email",    with: user.email
    fill_in "password", with: password
    click_button "Entrar"
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers,        type: :request
  config.include SystemAuthenticationHelpers,  type: :system
end
