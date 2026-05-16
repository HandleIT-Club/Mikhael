require "rails_helper"

RSpec.describe "Setup wizard (bootstrap del primer admin)", type: :request do
  describe "GET /setup" do
    context "cuando NO hay users" do
      it "responde 200 y muestra el form" do
        get setup_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Creá tu cuenta de administrador")
      end
    end

    context "cuando ya hay users" do
      before { create(:user) }

      it "redirige al login con alert (setup ya cerrado)" do
        get setup_path
        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to match(/setup ya fue completado/i)
      end
    end
  end

  describe "POST /setup" do
    let(:valid_params) do
      { user: { email: "admin@example.test", password: "supersecret123456" } }
    end

    context "cuando NO hay users" do
      it "crea el primer admin" do
        expect { post setup_path, params: valid_params }.to change(User, :count).by(1)
        user = User.last
        expect(user.email).to eq("admin@example.test")
        expect(user).to be_admin
      end

      it "loguea automáticamente y redirige a root" do
        post setup_path, params: valid_params
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(session[:user_id]).to eq(User.last.id)
      end

      it "deja el API token plain en flash[:reveal_token]" do
        post setup_path, params: valid_params
        expect(flash[:reveal_token]).to match(/\A[a-f0-9]{64}\z/)
      end

      it "acepta telegram_chat_id opcional" do
        post setup_path, params: { user: valid_params[:user].merge(telegram_chat_id: "12345") }
        expect(User.last.telegram_chat_id).to eq("12345")
      end

      it "re-renderiza con errores si password es corta" do
        post setup_path, params: { user: { email: "x@example.test", password: "corta" } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to match(/no se pudo crear/i)
        expect(User.count).to eq(0)
      end

      it "re-renderiza con errores si email es inválido" do
        post setup_path, params: { user: { email: "no-es-email", password: "supersecret123456" } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(User.count).to eq(0)
      end
    end

    context "cuando ya hay users (setup cerrado)" do
      before { create(:user) }

      it "no crea otro user — redirige al login" do
        expect { post setup_path, params: valid_params }.not_to change(User, :count)
        expect(response).to redirect_to(new_session_path)
      end

      it "rechaza incluso si intentás crear un admin (no se confía en el body)" do
        post setup_path, params: { user: valid_params[:user].merge(admin: "1") }
        expect(User.count).to eq(1) # solo el de before
      end
    end
  end

  describe "GET /session/new (login)" do
    context "cuando NO hay users" do
      it "redirige a /setup (auto-bootstrap)" do
        get new_session_path
        expect(response).to redirect_to(setup_path)
      end
    end

    context "cuando ya hay users" do
      before { create(:user) }

      it "muestra el form de login normal" do
        get new_session_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/iniciá sesión/i)
      end
    end
  end

  # ─── API JSON para el CLI (bin/mikhael primer arranque) ─────────────────
  describe "POST /setup (JSON)" do
    let(:json_headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }
    let(:valid_body)   { { user: { email: "cli@example.test", password: "supersecret123456" } } }

    context "cuando NO hay users" do
      it "crea el admin y devuelve { email, admin, api_token } con 201" do
        post setup_path, params: valid_body.to_json, headers: json_headers
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["email"]).to eq("cli@example.test")
        expect(body["admin"]).to be(true)
        expect(body["api_token"]).to match(/\A[a-f0-9]{64}\z/)
      end

      it "NO loguea al user (es para el CLI, no para session-based)" do
        post setup_path, params: valid_body.to_json, headers: json_headers
        expect(session[:user_id]).to be_nil
      end

      it "devuelve 422 con errors si validation falla" do
        post setup_path, params: { user: { email: "x@example.test", password: "corta" } }.to_json, headers: json_headers
        expect(response).to have_http_status(:unprocessable_content)
        body = JSON.parse(response.body)
        expect(body["errors"]).to be_an(Array)
        expect(body["errors"].join).to match(/password/i)
      end

      it "acepta telegram_chat_id opcional" do
        post setup_path,
             params: valid_body.deep_merge(user: { telegram_chat_id: "9999" }).to_json,
             headers: json_headers
        expect(User.last.telegram_chat_id).to eq("9999")
      end
    end

    context "cuando ya hay users (setup cerrado)" do
      before { create(:user) }

      it "devuelve 403 con { error: setup_already_completed }" do
        post setup_path, params: valid_body.to_json, headers: json_headers
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to eq("error" => "setup_already_completed")
      end

      it "no crea otro user" do
        expect { post setup_path, params: valid_body.to_json, headers: json_headers }.not_to change(User, :count)
      end
    end
  end
end
