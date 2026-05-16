require "rails_helper"

RSpec.describe "Api::V1::Devices", type: :request do
  let(:user)    { create(:user) }
  let(:headers) { { "Content-Type" => "application/json", "Accept" => "application/json", "Authorization" => "Bearer #{user.api_token}" } }

  describe "GET /api/v1/devices" do
    it "devuelve todos los dispositivos sin exponer el token" do
      create_list(:device, 2)
      get "/api/v1/devices", headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(2)
      expect(body.first).not_to have_key("token")
    end
  end

  describe "POST /api/v1/devices" do
    let(:valid_params) do
      {
        device: {
          device_id:     "riego_01",
          name:          "Riego automático",
          system_prompt: "Controlá el riego.",
          security_level: "normal"
        }
      }
    end

    it "crea un dispositivo y devuelve el token (única vez que se muestra)" do
      expect {
        post "/api/v1/devices", params: valid_params.to_json, headers: headers
      }.to change(Device, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["token"]).to be_present
    end

    it "retorna error con parámetros inválidos" do
      post "/api/v1/devices", params: { device: { device_id: "" } }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/devices/:id" do
    let(:device) { create(:device) }

    it "actualiza el system_prompt" do
      patch "/api/v1/devices/#{device.id}",
            params: { device: { system_prompt: "Nuevo prompt." } }.to_json,
            headers: headers
      expect(response).to have_http_status(:ok)
      expect(device.reload.system_prompt).to eq("Nuevo prompt.")
    end

    it "no expone el token al actualizar" do
      patch "/api/v1/devices/#{device.id}",
            params: { device: { security_level: "high" } }.to_json,
            headers: headers
      expect(JSON.parse(response.body)).not_to have_key("token")
    end
  end

  describe "POST /api/v1/devices/:id/regenerate_token" do
    let(:device) { create(:device) }

    it "regenera el token y lo devuelve" do
      old_token = device.token
      post "/api/v1/devices/#{device.id}/regenerate_token", headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body["token"]).not_to eq(old_token)
      expect(device.reload.token).to eq(body["token"])
    end
  end

  describe "DELETE /api/v1/devices/:id" do
    it "elimina el dispositivo" do
      device = create(:device)
      expect {
        delete "/api/v1/devices/#{device.id}", headers: headers
      }.to change(Device, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end
end
