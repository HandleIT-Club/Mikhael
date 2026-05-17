# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Resumen persistente de una conversación pasada, con keywords para retrieval.
#
# Se genera automáticamente cuando una conversación llega a TRIGGER_COUNT
# mensajes (vía GenerateMemoryJob) o manualmente con /resumir.
#
# El retrieval es simple: LIKE sobre keywords. Sin embeddings por ahora —
# escala bien para uso personal. Si se necesita semántica, pgvector en v3.
class Memory < ApplicationRecord
  TRIGGER_COUNT = 20  # alineado con AssistantContext::HISTORY_LIMIT_WITH_OVERRIDE
  MAX_RELEVANT  = 3

  belongs_to :user
  belongs_to :conversation, optional: true

  validates :summary,  presence: true
  validates :keywords, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # Busca las memories más relevantes para un mensaje dado, sin llamar al AI.
  # Hace LIKE sobre las keywords usando las palabras del mensaje raw.
  # Filtra palabras cortas (stopwords naturales) y limita a 8 términos de búsqueda.
  def self.relevant_for(user:, message:)
    words = message.downcase.scan(/\w{4,}/).uniq.first(8)
    return none if words.empty?

    clause = words.map { "keywords LIKE ?" }.join(" OR ")
    where(user: user)
      .where(clause, *words.map { |w| "%#{w}%" })
      .order(created_at: :desc)
      .limit(MAX_RELEVANT)
  end
end
