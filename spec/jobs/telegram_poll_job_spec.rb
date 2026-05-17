require "rails_helper"

RSpec.describe TelegramPollJob do
  include Dry::Monads[:result]

  let(:user)    { create(:user, :with_telegram) }
  let(:chat_id) { user.telegram_chat_id }

  before do
    allow(TelegramClient).to receive(:send_message)
    allow(TelegramClient).to receive(:get_updates).and_return({ "ok" => true, "result" => [] })
  end

  def text_update(text)
    { "update_id" => 1, "message" => { "chat" => { "id" => chat_id }, "text" => text } }
  end

  def voice_update(file_id: "file_abc123")
    { "update_id" => 2, "message" => { "chat" => { "id" => chat_id }, "voice" => { "file_id" => file_id } } }
  end

  describe "mensajes de texto (regresión)" do
    it "pasa el texto al handler sin llamar a Whisper" do
      allow(TelegramMessageHandler).to receive_message_chain(:new, :call)
      allow(Ai::WhisperClient).to receive(:new)

      described_class.new.send(:process, text_update("hola"))

      expect(Ai::WhisperClient).not_to have_received(:new)
      expect(TelegramMessageHandler).to have_received(:new).with(user: user, chat_id: chat_id)
    end
  end

  describe "mensajes de voz" do
    let(:whisper)    { instance_double(Ai::WhisperClient) }
    let(:audio_data) { "fake-audio-bytes" }

    before do
      stub_const("ENV", ENV.to_h.merge("GROQ_API_KEY" => "test-key"))
      allow(Ai::WhisperClient).to receive(:new).and_return(whisper)
      allow(TelegramClient).to receive(:get_file).and_return("voice/file_abc123.oga")
      allow(TelegramClient).to receive(:download_file).and_return(audio_data)
    end

    context "cuando Whisper transcribe con éxito" do
      before do
        allow(whisper).to receive(:transcribe).and_return(Success("apagá la luz"))
        allow(TelegramMessageHandler).to receive_message_chain(:new, :call)
      end

      it "pasa el texto transcripto al handler" do
        described_class.new.send(:process, voice_update)
        expect(TelegramMessageHandler).to have_received(:new).with(user: user, chat_id: chat_id)
      end

      it "no manda mensaje de error al usuario" do
        described_class.new.send(:process, voice_update)
        expect(TelegramClient).not_to have_received(:send_message)
      end
    end

    context "cuando Whisper devuelve rate_limited (429)" do
      before { allow(whisper).to receive(:transcribe).and_return(Failure(:rate_limited)) }

      it "avisa al usuario del límite diario" do
        described_class.new.send(:process, voice_update)
        expect(TelegramClient).to have_received(:send_message)
          .with(/límite diario/, chat_id: chat_id)
      end

      it "no llama al handler" do
        allow(TelegramMessageHandler).to receive_message_chain(:new, :call)
        described_class.new.send(:process, voice_update)
        expect(TelegramMessageHandler).not_to have_received(:new)
      end
    end

    context "cuando Whisper devuelve ai_error" do
      before { allow(whisper).to receive(:transcribe).and_return(Failure(:ai_error)) }

      it "avisa al usuario que no pudo entender el audio" do
        described_class.new.send(:process, voice_update)
        expect(TelegramClient).to have_received(:send_message)
          .with(/No pude entender/, chat_id: chat_id)
      end
    end

    context "cuando get_file devuelve nil" do
      before { allow(TelegramClient).to receive(:get_file).and_return(nil) }

      it "avisa al usuario y no llama a Whisper" do
        described_class.new.send(:process, voice_update)
        expect(TelegramClient).to have_received(:send_message)
          .with(/No pude acceder/, chat_id: chat_id)
        expect(Ai::WhisperClient).not_to have_received(:new)
      end
    end

    context "cuando download_file devuelve nil" do
      before { allow(TelegramClient).to receive(:download_file).and_return(nil) }

      it "avisa al usuario y no llama a Whisper" do
        described_class.new.send(:process, voice_update)
        expect(TelegramClient).to have_received(:send_message)
          .with(/No pude descargar/, chat_id: chat_id)
        expect(Ai::WhisperClient).not_to have_received(:new)
      end
    end

    context "cuando GROQ_API_KEY no está configurada" do
      before { stub_const("ENV", ENV.to_h.merge("GROQ_API_KEY" => "")) }

      it "avisa al usuario que la feature está deshabilitada" do
        described_class.new.send(:process, voice_update)
        expect(TelegramClient).to have_received(:send_message)
          .with(/deshabilitada/, chat_id: chat_id)
        expect(Ai::WhisperClient).not_to have_received(:new)
      end
    end
  end
end
