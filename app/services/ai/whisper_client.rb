# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
require "net/http"
require "json"
require "securerandom"

module Ai
  # Cliente para la API de transcripción de audio de Groq (Whisper).
  # No extiende BaseClient porque no es un cliente de chat.
  #
  # Reutiliza GROQ_API_KEY — no requiere nueva ENV var.
  #
  # Límites gratuitos de Groq Whisper:
  #   2 000 req/día · 28 800 s de audio/día
  # Si se alcanza el límite, devuelve Failure(:rate_limited) — sin fallback.
  class WhisperClient
    include Dry::Monads[:result]

    ENDPOINT = "https://api.groq.com/openai/v1/audio/transcriptions".freeze
    MODEL     = "whisper-large-v3-turbo".freeze

    # audio_data: string binario (bytes del .ogg u otro formato soportado)
    # filename:   nombre con extensión — Telegram manda OGG para notas de voz
    # language:   código ISO 639-1 (ej. "es", "en") — mejora la precisión
    #             y evita detección automática errónea. nil = auto-detect.
    #
    # Devuelve:
    #   Success(String)               texto transcripto
    #   Failure(:whisper_unavailable) GROQ_API_KEY no configurada
    #   Failure(:rate_limited)        429 de Groq (límite diario alcanzado)
    #   Failure(:ai_error)            cualquier otro fallo
    def transcribe(audio_data, filename: "voice.ogg", language: nil)
      key = ENV["GROQ_API_KEY"].presence
      return Failure(:whisper_unavailable) if key.blank?

      boundary = "----MikhaelWhisper#{SecureRandom.hex(8)}"
      body     = build_multipart(audio_data, filename, boundary, language: language)

      uri = URI(ENDPOINT)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 30, open_timeout: 5) do |http|
        req                 = Net::HTTP::Post.new(uri)
        req["Authorization"] = "Bearer #{key}"
        req["Content-Type"]  = "multipart/form-data; boundary=#{boundary}"
        req.body             = body

        handle_response(http.request(req))
      end
    rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("WhisperClient: #{e.class} — #{e.message}")
      Failure(:ai_error)
    end

    private

    def handle_response(response)
      case response.code.to_i
      when 200
        text = JSON.parse(response.body)["text"].to_s.strip
        text.present? ? Success(text) : Failure(:ai_error)
      when 429
        Rails.logger.warn("WhisperClient: límite diario de Groq alcanzado (429)")
        Failure(:rate_limited)
      when 401, 403
        Failure(:whisper_unavailable)
      else
        Rails.logger.error("WhisperClient: error #{response.code}: #{response.body.to_s.truncate(200)}")
        Failure(:ai_error)
      end
    end

    def build_multipart(audio_data, filename, boundary, language: nil)
      crlf = "\r\n"
      body = +"--#{boundary}#{crlf}"
      body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"#{crlf}"
      body << "Content-Type: audio/ogg#{crlf}#{crlf}"
      body << audio_data
      body << "#{crlf}--#{boundary}#{crlf}"
      body << "Content-Disposition: form-data; name=\"model\"#{crlf}#{crlf}"
      body << MODEL
      if language.present?
        body << "#{crlf}--#{boundary}#{crlf}"
        body << "Content-Disposition: form-data; name=\"language\"#{crlf}#{crlf}"
        body << language
      end
      body << "#{crlf}--#{boundary}--#{crlf}"
      body.force_encoding("BINARY")
    end
  end
end
