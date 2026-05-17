# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class MemoriesController < ApplicationController
  before_action :set_memory, only: %i[destroy]

  def index
    @memories = current_user.memories.recent
    @query    = params[:q].to_s.strip
    @memories = @memories.where("keywords LIKE ?", "%#{@query}%") if @query.present?
  end

  def destroy
    @memory.destroy
    redirect_to memories_path, status: :see_other, notice: "Memoria eliminada."
  end

  private

  def set_memory
    @memory = current_user.memories.find(params[:id])
  end
end
