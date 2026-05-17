# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Genera un resumen (Memory) de una conversación usando el AI.
#
# Se encola cuando la conversación llega a Memory::TRIGGER_COUNT mensajes
# (desde ProcessUserMessage) o se llama sincrónico desde el comando /resumir.
#
# Flujo:
#   1. Busca la conversación y el user.
#   2. Toma los chat_messages completos (no context_messages) para resumir todo.
#   3. Llama al AI con un prompt específico que devuelve JSON: { summary, keywords }.
#   4. Persiste la Memory.
#   5. Setea context_cutoff_at en la conversación para que el AI ignore lo resumido.
#
# Idempotente: si la conversación tiene menos de TRIGGER_COUNT mensajes, no hace nada.
# No persiste mensajes nuevos en la conversación.
class GenerateMemoryJob < ApplicationJob
  queue_as :default

  SUMMARY_PROMPT = <<~PROMPT.strip.freeze
    Resumí la conversación que sigue en un JSON con exactamente esta forma:
    {"summary":"...","keywords":"..."}

    Reglas:
    - summary: 3-5 oraciones en primera persona desde la perspectiva del usuario. Qué pidió, qué se resolvió, decisiones importantes.
    - keywords: lista de 5-10 palabras clave separadas por comas, en minúscula, sin artículos ni preposiciones. Conceptos concretos: nombres de proyectos, tecnologías, acciones, temas tratados.
    - Respondé SOLO con el JSON. Sin prosa, sin markdown, sin explicaciones.
  PROMPT

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    messages = conversation.chat_messages.to_a
    return if messages.size < Memory::TRIGGER_COUNT

    Rails.logger.tagged("GenerateMemoryJob", "conv=#{conversation_id}") do
      Rails.logger.info("generando memory para #{messages.size} mensajes")
      generate(conversation, messages)
    end
  rescue => e
    Rails.logger.error("GenerateMemoryJob#perform(#{conversation_id}): #{e.class} — #{e.message}")
  end

  private

  def generate(conversation, messages)
    chat_history = messages.map { |m| { role: m.role, content: m.content } }
    payload = [ { role: "system", content: SUMMARY_PROMPT } ] + chat_history

    result = Ai::Dispatcher.for(conversation.provider)
                           .chat(messages: payload, model: conversation.model_id)

    unless result.success?
      Rails.logger.warn("GenerateMemoryJob: AI falló — #{result.failure}")
      return
    end

    parsed = parse_response(result.value!.content)
    return unless parsed

    Memory.create!(
      user:         conversation.user,
      conversation: conversation,
      summary:      parsed[:summary],
      keywords:     parsed[:keywords]
    )

    conversation.update!(context_cutoff_at: Time.current)
    Rails.logger.info("GenerateMemoryJob: memory creada para conv=#{conversation.id}")
  end

  def parse_response(content)
    json = JSON.parse(content.to_s.strip.then { |s|
      # Extraer JSON si el modelo lo envolvió en markdown
      s.match(/\{.*\}/m)&.to_s || s
    })
    summary  = json["summary"].to_s.strip
    keywords = json["keywords"].to_s.strip
    return nil if summary.blank? || keywords.blank?

    { summary: summary, keywords: keywords }
  rescue JSON::ParserError => e
    Rails.logger.warn("GenerateMemoryJob: JSON inválido — #{e.message}")
    nil
  end
end
