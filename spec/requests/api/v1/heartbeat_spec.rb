require "rails_helper"

RSpec.describe "POST /api/v1/heartbeat", type: :request do
  let(:device) { create(:device) }
  let(:headers) { { "Authorization" => "Bearer #{device.token}" } }

  it "actualiza last_seen_at y devuelve ok" do
    expect {
      post "/api/v1/heartbeat", headers: headers
    }.to change { device.reload.last_seen_at }

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["ok"]).to be true
    expect(body["device_id"]).to eq(device.device_id)
    expect(body["last_seen_at"]).to be_present
  end

  it "rechaza tokens inválidos" do
    post "/api/v1/heartbeat", headers: { "Authorization" => "Bearer token_falso" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "rechaza requests sin token" do
    post "/api/v1/heartbeat"
    expect(response).to have_http_status(:unauthorized)
  end
end
