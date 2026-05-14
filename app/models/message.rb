# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class Message < ApplicationRecord
  belongs_to :conversation

  ROLES = %w[system user assistant].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :content, presence: true

  scope :ordered, -> { order(:created_at) }
end
