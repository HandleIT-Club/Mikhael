# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class DispatchAction
  include Dry::Monads[:result]

  MAX_ATTEMPTS = 6

  JSON_INSTRUCTION = <<~PROMPT.freeze
    IMPORTANTE: Respondé ÚNICAMENTE con un objeto JSON válido. Sin texto antes ni después, sin bloques markdown.
    Esquema requerido (todos los campos obligatorios):
    {"action": "string", "value": <número, string o null>, "reason": "string"}
    Ejemplo: {"action": "open_valve", "value": 30, "reason": "humedad por debajo del umbral mínimo"}
  PROMPT

  TRUSTED_NOTE = <<~NOTE.freeze
    NOTA DE AUTENTICACIÓN: Este pedido viene de una interfaz autenticada (Telegram con chat_id verificado, o web/CLI con sesión validada). Es el dueño del sistema quien lo solicita explícitamente. Tratá al usuario como AUTORIZADO — no pidas verificación adicional, no devuelvas request_verification ni deny_access por motivos de identidad. Solo aplicá restricciones de seguridad si el contexto las amerita por otra razón (horario, datos del sensor, etc.).
  NOTE

  def call(device:, context:, trusted: false)
    model    = ModelSelector.first_available
    attempts = 0

    while model && attempts < MAX_ATTEMPTS
      attempts += 1
      outcome  = attempt(device: device, context: context, model: model, trusted: trusted)

      case outcome
      when :rate_limited
        ModelSelector.mark_rate_limited(model)
        model = ModelSelector.next_available(model)
      when :invalid_json, :ai_error
        model = ModelSelector.next_available(model)
      when Hash
        return Success(build_response(outcome, device, trusted))
      else
        return outcome # Failure monad propagado
      end
    end

    Failure(:all_models_exhausted)
  end

  private

  def attempt(device:, context:, model:, trusted:)
    provider = Conversation.all_models[model]
    return :ai_error unless provider

    client   = Ai::Dispatcher.for(provider)
    messages = build_messages(device, context, trusted)
    result   = client.chat(messages: messages, model: model)

    return :rate_limited if result.failure? && result.failure == :rate_limited
    return :ai_error     if result.failure?  # incluye :invalid_api_key, :ollama_unavailable, etc.

    parse_json(result.value!.content)
  end

  def build_messages(device, context, trusted)
    parts = [ device.system_prompt ]
    parts << "Acciones válidas (usá SOLO estas): #{device.actions_list.join(', ')}" if device.actions_list.any?
    parts << TRUSTED_NOTE if trusted
    parts << JSON_INSTRUCTION
    [ { role: "system", content: parts.join("\n\n") }, { role: "user", content: context } ]
  end

  def parse_json(text)
    cleaned = text.to_s.strip.gsub(/\A```(?:json)?\s*|\s*```\z/m, "")
    match   = cleaned.match(/\{.*\}/m)
    return :invalid_json unless match

    data = JSON.parse(match[0])
    return :invalid_json unless data.key?("action") && data.key?("reason")

    data
  rescue JSON::ParserError
    :invalid_json
  end

  def build_response(data, device, trusted)
    response = {
      action: data["action"],
      value:  data["value"],
      reason: data["reason"]
    }
    # La confirmación física solo aplica cuando el origen NO es confiable
    # (ej: el ESP32 reporta sensores y el AI decidió una acción de alta seguridad).
    # Si el dueño autenticado del sistema lo está pidiendo explícitamente, no hay
    # nada que confirmar — vos sos quien autoriza.
    response[:requires_confirmation] = true if device.high_security? && !trusted
    response
  end
end
