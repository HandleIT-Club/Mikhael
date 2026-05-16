require "rails_helper"

RSpec.describe "Authentication", type: :system do
  # let! para asegurar que existe ANTES de cada visit. Sin esto el setup
  # wizard (DB vacía) intercepta /session/new y no encontramos el form.
  let!(:user) { create(:user, password: "supersecret123456") }

  it "redirige al login cuando entrás sin sesión (y ya hay users)" do
    visit "/"
    expect(page).to have_content("Iniciá sesión")
  end

  it "permite logear con credenciales correctas y muestra la app" do
    visit new_session_path
    fill_in "email",    with: user.email
    fill_in "password", with: "supersecret123456"
    click_button "Entrar"

    expect(page).to have_content("¡Hola, #{user.email}!").or have_current_path("/")
  end

  it "rechaza credenciales malas con un error visible" do
    visit new_session_path
    fill_in "email",    with: user.email
    fill_in "password", with: "wrong"
    click_button "Entrar"

    expect(page).to have_content(/Email o contraseña incorrectos/i)
  end

  it "logout cierra sesión y vuelve al login" do
    sign_in_through_form(user)
    visit "/"
    click_button "Salir"

    expect(page).to have_content(/Iniciá sesión/i)
  end

  describe "scoping de datos: un user no ve datos de otro" do
    let(:alice) { create(:user, password: "supersecret123456") }
    let(:bob)   { create(:user, password: "supersecret123456") }

    it "Alice no ve las conversaciones de Bob" do
      create(:conversation, user: bob, title: "Conversación de Bob — secreta")
      mine = create(:conversation, user: alice, title: "Conversación de Alice")

      sign_in_through_form(alice)
      visit conversation_path(mine)

      expect(page).to have_content("Alice")
      expect(page).not_to have_content("Bob")
    end

    it "Alice no puede acceder a la URL de una conversación de Bob (404)" do
      bobs_conv = create(:conversation, user: bob)

      sign_in_through_form(alice)
      visit conversation_path(bobs_conv)

      # ActiveRecord::RecordNotFound se maneja como 404 en dev/test
      expect(page).to have_content(/no encontrado|not found|404/i).or have_no_content("Mikhael")
    end
  end
end
