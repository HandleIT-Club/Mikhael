# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Api
  module V1
    class MemoriesController < BaseController
      def index
        memories = Current.user.memories.recent
        memories = memories.where("keywords LIKE ?", "%#{params[:q]}%") if params[:q].present?
        render json: memories.map { |m| serialize(m) }
      end

      def destroy
        memory = Current.user.memories.find(params[:id])
        memory.destroy
        head :no_content
      end

      private

      def serialize(memory)
        {
          id:         memory.id,
          summary:    memory.summary,
          keywords:   memory.keywords,
          created_at: memory.created_at
        }
      end
    end
  end
end
