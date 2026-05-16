# Helper compartido para specs que tocan el flujo AI.
#
# Problema que resuelve: ModelSelector lee ENV (GROQ_API_KEY etc.) para
# construir la fallback_chain. En test ENV está vacío → first_available
# devuelve nil → DispatchAction falla con :all_models_exhausted antes de
# llegar al Ai::Dispatcher mockeado. Eso rompía 12 specs sin razón.
#
# Uso:
#   before { stub_ai_provider!("llama-3.3-70b-versatile") }
#
# Si no pasás modelo, usa el default (llama 3.3 70b en groq).

module AiProviderStubs
  DEFAULT_MODEL = "llama-3.3-70b-versatile".freeze

  def stub_ai_provider!(model = DEFAULT_MODEL)
    allow(ModelSelector).to receive(:first_available).and_return(model)
    allow(ModelSelector).to receive(:next_available).and_return(nil)
    allow(ModelSelector).to receive(:next_available_cloud).and_return(nil)
    allow(ModelSelector).to receive(:mark_rate_limited)
  end
end

RSpec.configure do |config|
  config.include AiProviderStubs
end
