require "rails_helper"

RSpec.describe TelegramClient do
  before do
    ENV["TELEGRAM_BOT_TOKEN"] = "test:token"
    described_class.reset_connection!
  end

  after do
    ENV.delete("TELEGRAM_BOT_TOKEN")
    described_class.reset_connection!
  end

  describe ".send_message" do
    let(:chat_id) { "12345" }

    it "no manda si TELEGRAM_BOT_TOKEN está ausente" do
      ENV.delete("TELEGRAM_BOT_TOKEN")
      expect(described_class).not_to receive(:post)
      described_class.send_message("hola", chat_id: chat_id)
    end

    it "no manda si chat_id está vacío" do
      expect(described_class).not_to receive(:post)
      described_class.send_message("hola", chat_id: "")
    end

    it "manda con parse_mode=Markdown cuando todo OK" do
      stub = stub_request(:post, "https://api.telegram.org/bottest:token/sendMessage")
             .with(body: hash_including(text: "hola", parse_mode: "Markdown"))
             .to_return(status: 200, body: { ok: true, result: {} }.to_json)

      described_class.send_message("hola", chat_id: chat_id)
      expect(stub).to have_been_requested
    end

    context "cuando Telegram rechaza el Markdown (parse error 400)" do
      let(:markdown_error_body) do
        {
          ok: false,
          error_code: 400,
          description: "Bad Request: can't parse entities: Can't find end of the entity..."
        }.to_json
      end

      it "reintenta sin parse_mode (texto plano)" do
        # Primera llamada con Markdown → 400
        first = stub_request(:post, "https://api.telegram.org/bottest:token/sendMessage")
                .with(body: hash_including(parse_mode: "Markdown"))
                .to_return(status: 400, body: markdown_error_body)

        # Segunda llamada SIN parse_mode → 200
        retry_stub = stub_request(:post, "https://api.telegram.org/bottest:token/sendMessage")
                     .with { |req| !JSON.parse(req.body).key?("parse_mode") }
                     .to_return(status: 200, body: { ok: true, result: {} }.to_json)

        described_class.send_message("texto_con_underscore_no_balanceado", chat_id: chat_id)

        expect(first).to have_been_requested
        expect(retry_stub).to have_been_requested
      end
    end

    context "cuando Telegram rechaza por otra razón (NO markdown)" do
      let(:other_error_body) do
        { ok: false, error_code: 403, description: "Forbidden: bot was blocked by the user" }.to_json
      end

      it "NO reintenta — devuelve el error como vino" do
        stub = stub_request(:post, "https://api.telegram.org/bottest:token/sendMessage")
               .to_return(status: 403, body: other_error_body)

        described_class.send_message("hola", chat_id: chat_id)
        # Una sola request — el error 403 no se reintenta
        expect(stub).to have_been_requested.once
      end
    end
  end

  describe ".markdown_parse_error?" do
    it "true para error 400 con descripción de can't parse entities" do
      expect(described_class.markdown_parse_error?(
        "error_code" => 400,
        "description" => "Bad Request: can't parse entities: ..."
      )).to be(true)
    end

    it "false para otros 400" do
      expect(described_class.markdown_parse_error?(
        "error_code" => 400,
        "description" => "Bad Request: chat not found"
      )).to be(false)
    end

    it "false para errores que no son 400" do
      expect(described_class.markdown_parse_error?(
        "error_code" => 429,
        "description" => "Too Many Requests"
      )).to be(false)
    end
  end
end
