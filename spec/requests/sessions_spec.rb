require "rails_helper"

RSpec.describe "Sessions", type: :request do
  # admin para que `/devices` no rebote en require_admin! cuando testeamos
  # return_to abajo.
  let(:user) { create(:user, :admin, password: "supersecret123456") }

  describe "GET /session/new" do
    it "muestra el form de login (con users en la DB)" do
      user # crea el user antes — sin esto cae al setup wizard
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Iniciá sesión")
    end

    it "redirige al root si ya estás logueado" do
      sign_in_as(user)
      get new_session_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /session" do
    it "con credenciales correctas: redirige y crea sesión" do
      post session_path, params: { email: user.email, password: "supersecret123456" }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(session[:user_id]).to eq(user.id)
    end

    it "con email incorrecto: mensaje genérico (no leak de existencia)" do
      post session_path, params: { email: "nope@example.test", password: "supersecret123456" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to match(/Email o contraseña incorrectos/i)
    end

    it "con password incorrecto: mismo mensaje genérico" do
      post session_path, params: { email: user.email, password: "incorrecta" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to match(/Email o contraseña incorrectos/i)
    end

    it "preserva return_to: tras login redirige a donde quería ir antes" do
      # Visita protegida sin login → guarda return_to
      get "/devices"
      expect(response).to redirect_to(new_session_path)
      # Login
      post session_path, params: { email: user.email, password: "supersecret123456" }
      expect(response).to redirect_to("/devices")
    end

    it "reset_session previene fixation: el session_id cambia tras login" do
      get new_session_path
      old_id = session.id
      post session_path, params: { email: user.email, password: "supersecret123456" }
      expect(session.id).not_to eq(old_id)
    end
  end

  describe "DELETE /session (logout)" do
    before { sign_in_as(user) }

    it "cierra sesión y redirige a login" do
      delete session_path
      expect(response).to redirect_to(new_session_path)
      expect(session[:user_id]).to be_nil
    end
  end

  describe "authenticate_user! middleware" do
    it "rutas protegidas redirigen a login sin sesión" do
      get conversations_path
      expect(response).to redirect_to(new_session_path)
    end

    it "API JSON sin Bearer responde 401" do
      get "/api/v1/conversations", headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
