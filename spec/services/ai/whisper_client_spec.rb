require "rails_helper"

RSpec.describe Ai::WhisperClient do
  subject(:client) { described_class.new }

  let(:audio_data) { "fake-audio-bytes" }
  let(:groq_url)   { "https://api.groq.com/openai/v1/audio/transcriptions" }

  describe "#transcribe" do
    context "cuando GROQ_API_KEY no está configurada" do
      before { stub_const("ENV", ENV.to_h.merge("GROQ_API_KEY" => "")) }

      it "devuelve Failure(:whisper_unavailable)" do
        result = client.transcribe(audio_data)
        expect(result).to be_failure
        expect(result.failure).to eq(:whisper_unavailable)
      end
    end

    context "cuando GROQ_API_KEY está configurada" do
      before { stub_const("ENV", ENV.to_h.merge("GROQ_API_KEY" => "test-key")) }

      context "con respuesta 200" do
        before do
          stub_request(:post, groq_url)
            .to_return(status: 200, body: { text: "encendé la luz" }.to_json)
        end

        it "devuelve Success con el texto transcripto" do
          result = client.transcribe(audio_data)
          expect(result).to be_success
          expect(result.value!).to eq("encendé la luz")
        end
      end

      context "con respuesta 429 (límite diario)" do
        before do
          stub_request(:post, groq_url)
            .to_return(status: 429, body: { error: { message: "rate limit" } }.to_json)
        end

        it "devuelve Failure(:rate_limited)" do
          result = client.transcribe(audio_data)
          expect(result).to be_failure
          expect(result.failure).to eq(:rate_limited)
        end
      end

      context "con respuesta 401" do
        before do
          stub_request(:post, groq_url)
            .to_return(status: 401, body: { error: { message: "unauthorized" } }.to_json)
        end

        it "devuelve Failure(:whisper_unavailable)" do
          result = client.transcribe(audio_data)
          expect(result).to be_failure
          expect(result.failure).to eq(:whisper_unavailable)
        end
      end

      context "con respuesta 500" do
        before do
          stub_request(:post, groq_url)
            .to_return(status: 500, body: "Internal Server Error")
        end

        it "devuelve Failure(:ai_error)" do
          result = client.transcribe(audio_data)
          expect(result).to be_failure
          expect(result.failure).to eq(:ai_error)
        end
      end

      context "cuando hay un error de red" do
        before do
          stub_request(:post, groq_url).to_raise(SocketError.new("failed to connect"))
        end

        it "devuelve Failure(:ai_error)" do
          result = client.transcribe(audio_data)
          expect(result).to be_failure
          expect(result.failure).to eq(:ai_error)
        end
      end
    end
  end
end
