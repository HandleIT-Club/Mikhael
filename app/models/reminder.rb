# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

class Reminder < ApplicationRecord
  belongs_to :device, optional: true

  enum :kind, { notify: "notify", query_device: "query_device" }, validate: true

  validates :scheduled_for, presence: true
  validates :message,       presence: true
  validates :kind,          presence: true
  validate  :device_required_for_query

  scope :pending,  -> { where(executed_at: nil).order(:scheduled_for) }
  scope :upcoming, -> { pending.where("scheduled_for > ?", Time.current) }

  def pending?
    executed_at.nil?
  end

  private

  def device_required_for_query
    return unless kind == "query_device"
    errors.add(:device_id, "es requerido para kind=query_device") if device_id.blank?
  end
end
