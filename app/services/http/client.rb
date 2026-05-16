# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Factory de conexiones Faraday con:
#   - Retries automáticos con backoff exponencial (2 reintentos por default).
#   - Reintenta en 429 / 502 / 503 / 504 + excepciones de conexión/timeout.
#   - Timeouts uniformes (open/read).
#   - Logger opcional para debug.
#
# Antes cada client (Telegram, providers AI, Ollama) tenía su propio
# Net::HTTP, sin retries, con manejo de timeouts ad-hoc. Esto centraliza.
require "faraday"
require "faraday/retry"

module Http
  class Client
    DEFAULT_TIMEOUT      = 30
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_RETRIES      = 2

    RETRY_STATUSES = [ 429, 502, 503, 504 ].freeze
    RETRY_EXCEPTIONS = [
      Faraday::TimeoutError,
      Faraday::ConnectionFailed,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EPIPE
    ].freeze

    # Construye una connection Faraday lista para usar.
    #
    # base_url:    "https://api.foo.com" (obligatorio)
    # headers:     headers default (auth, content-type, etc.)
    # timeout:     read timeout en segundos
    # open_timeout: connect timeout en segundos
    # retries:     número de reintentos (0 desactiva)
    def self.connection(base_url:, headers: {}, timeout: DEFAULT_TIMEOUT, open_timeout: DEFAULT_OPEN_TIMEOUT, retries: DEFAULT_RETRIES)
      Faraday.new(url: base_url, headers: headers) do |conn|
        if retries.positive?
          conn.request :retry,
                       max: retries,
                       interval:         0.5,
                       backoff_factor:   2,
                       methods:          %i[get post],
                       retry_statuses:   RETRY_STATUSES,
                       exceptions:       RETRY_EXCEPTIONS,
                       retry_block:      ->(env:, options:, retry_count:, exception:, will_retry_in:) do
                         Rails.logger.warn(
                           "[Http] retry ##{retry_count + 1} a #{env.url} en #{will_retry_in}s " \
                           "(status=#{env.response&.status} ex=#{exception&.class})"
                         )
                       end
        end

        conn.options.timeout      = timeout
        conn.options.open_timeout = open_timeout
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
