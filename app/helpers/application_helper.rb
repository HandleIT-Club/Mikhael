# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module ApplicationHelper
  PROVIDER_BADGE = {
    "groq"      => { label: "☁️ Groq",      css: "bg-amber-500/10 text-amber-400 border border-amber-500/30" },
    "cerebras"  => { label: "☁️ Cerebras",   css: "bg-blue-500/10 text-blue-400 border border-blue-500/30" },
    "sambanova" => { label: "☁️ SambaNova",  css: "bg-purple-500/10 text-purple-400 border border-purple-500/30" },
    "ollama"    => { label: "🖥️ local",      css: "bg-zinc-800 text-zinc-400 border border-zinc-700" }
  }.freeze

  PROVIDER_NAMES = {
    "groq"      => "Groq",
    "cerebras"  => "Cerebras",
    "sambanova" => "SambaNova",
    "ollama"    => "Ollama"
  }.freeze

  def provider_badge(provider)
    PROVIDER_BADGE[provider] || PROVIDER_BADGE["ollama"]
  end

  def provider_name(provider)
    PROVIDER_NAMES[provider] || provider.to_s.capitalize
  end

  def conversation_model_options
    ollama = OllamaModels.installed.map { |m| [ m, m ] }
    groups = {
      "Groq – Avanzado"     => ModelSelector::GROQ_TIERS[:advanced].map { |m| [ m, m ] },
      "Groq – Intermedio"   => ModelSelector::GROQ_TIERS[:intermediate].map { |m| [ m, m ] },
      "Groq – Básico"       => ModelSelector::GROQ_TIERS[:basic].map { |m| [ m, m ] },
      "Cerebras"            => ModelSelector::CEREBRAS_TIERS.values.flatten.map { |m| [ m, m ] },
      "SambaNova"           => ModelSelector::SAMBANOVA_TIERS.values.flatten.map { |m| [ m, m ] }
    }
    groups["Ollama (local)"] = ollama if ollama.any?
    groups
  end

  def render_markdown(text)
    renderer = Redcarpet::Render::HTML.new(
      filter_html: false,
      hard_wrap: true,
      with_toc_data: false
    )
    markdown = Redcarpet::Markdown.new(renderer,
      fenced_code_blocks: true,
      autolink: true,
      strikethrough: true,
      no_intra_emphasis: true
    )
    markdown.render(text).html_safe
  end
end
