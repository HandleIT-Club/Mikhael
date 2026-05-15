# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
require "net/http"
require "json"

module Ai
  # Para providers con API OpenAI-compatible que no podemos rutear por RubyLLM
  # porque openai_api_base ya está reservado por Groq.
  class OpenAiCompatibleClient < BaseClient
    def chat(messages:, model:)
      key = api_key
      return Failure(:invalid_api_key) if key.blank?

      actual_model = strip_prefix(model)
      formatted    = format_messages(messages)
      response     = post_completion(actual_model, formatted, key)

      handle_response(response, model)
    rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("#{self.class} connection error: #{e.message}")
      Failure(:ai_error)
    end

    def stream(messages:, model:, &block)
      key = api_key
      return Failure(:invalid_api_key) if key.blank?

      actual_model   = strip_prefix(model)
      formatted      = format_messages(messages)
      full_content   = +""

      uri = URI("#{self.class.api_base}/chat/completions")
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) do |http|
        req = Net::HTTP::Post.new(uri)
        req["Authorization"] = "Bearer #{key}"
        req["Content-Type"]  = "application/json"
        req.body = { model: actual_model, messages: formatted, stream: true }.to_json

        http.request(req) do |response|
          case response.code.to_i
          when 429        then return Failure(:rate_limited)
          when 401, 403   then return Failure(:invalid_api_key)
          when 200
            parse_sse_stream(response, full_content, &block)
          else
            return Failure(:ai_error)
          end
        end
      end

      build_response(full_content, model, provider_name)
    rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("#{self.class} stream error: #{e.message}")
      Failure(:ai_error)
    end

    private

    def parse_sse_stream(response, full_content, &block)
      buffer = +""
      response.read_body do |raw|
        buffer << raw
        while (newline = buffer.index("\n"))
          line = buffer.slice!(0, newline + 1).strip
          next unless line.start_with?("data: ")
          data = line.delete_prefix("data: ")
          next if data == "[DONE]"
          begin
            delta = JSON.parse(data).dig("choices", 0, "delta", "content").to_s
            if delta.present?
              full_content << delta
              block&.call(delta)
            end
          rescue JSON::ParseError
            # fragmento malformado — ignorar y continuar
          end
        end
      end
    end

    def handle_response(response, model)
      case response.code.to_i
      when 200
        data    = JSON.parse(response.body)
        content = data.dig("choices", 0, "message", "content").to_s
        build_response(content, model, provider_name)
      when 429
        Failure(:rate_limited)
      when 401, 403
        Failure(:invalid_api_key)
      else
        Rails.logger.error("#{self.class} error #{response.code}: #{response.body.truncate(200)}")
        Failure(:ai_error)
      end
    end

    def post_completion(model, messages, key)
      uri = URI("#{self.class.api_base}/chat/completions")
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60) do |http|
        req = Net::HTTP::Post.new(uri)
        req["Authorization"]  = "Bearer #{key}"
        req["Content-Type"]   = "application/json"
        req.body = { model: model, messages: messages }.to_json
        http.request(req)
      end
    end

    def format_messages(messages)
      messages.map { |m| { role: m[:role], content: m[:content] } }
    end

    def strip_prefix(model)
      model.sub(/\A#{self.class.model_prefix}\//, "")
    end
  end
end
