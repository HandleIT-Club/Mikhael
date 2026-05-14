# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class ModelConfigsController < ApplicationController
  def index
    @configs = Conversation.all_models.keys.map { |model_id| ModelConfig.find_or_create_default(model_id) }
  end

  def update
    config = ModelConfig.find(params[:id])
    if config.update(model_config_params)
      redirect_to model_configs_path, notice: "Contexto de #{config.model_id} actualizado."
    else
      redirect_to model_configs_path, alert: config.errors.full_messages.to_sentence
    end
  end

  private

  def model_config_params
    params.expect(model_config: [ :system_prompt ])
  end
end
