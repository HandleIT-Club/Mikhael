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

  # Opciones agrupadas para el select de modelo. La lista viene del
  # registry — un solo punto de verdad.
  def conversation_model_options
    groups = {}
    Ai::ModelRegistry::CLOUD_PROVIDERS.each do |provider, cfg|
      cfg[:tiers].each do |tier, models|
        label = "#{provider_name(provider)} – #{tier.to_s.capitalize}"
        groups[label] = models.map { |m| [ m, m ] }
      end
    end
    ollama = OllamaModels.installed.map { |m| [ m, m ] }
    groups["Ollama (local)"] = ollama if ollama.any?
    groups
  end

  # Allowlist de tags y atributos para el output del AI. Si el modelo escupe
  # <script>, <iframe>, on*=…, javascript:, etc., el sanitizer los strippea.
  # Esto cierra XSS por prompt injection o respuestas malformadas del LLM.
  MARKDOWN_ALLOWED_TAGS = %w[
    p br hr
    strong em del code pre blockquote
    h1 h2 h3 h4 h5 h6
    ul ol li
    a
    table thead tbody tr th td
  ].freeze

  MARKDOWN_ALLOWED_ATTRIBUTES = %w[href title class].freeze

  def render_markdown(text)
    renderer = Redcarpet::Render::HTML.new(
      filter_html:   true,   # primer filtro: Redcarpet escapa HTML del input
      hard_wrap:     true,
      with_toc_data: false,
      safe_links_only: true  # rechaza javascript:, data:, vbscript: URIs
    )
    markdown = Redcarpet::Markdown.new(renderer,
      fenced_code_blocks: true,
      autolink:           true,
      strikethrough:      true,
      no_intra_emphasis:  true,
      tables:             true
    )
    # Doble red: aunque filter_html ya escapó, sanitize con allowlist explícita
    # garantiza que ningún tag/atributo fuera de la lista llegue al DOM.
    sanitize(markdown.render(text), tags: MARKDOWN_ALLOWED_TAGS, attributes: MARKDOWN_ALLOWED_ATTRIBUTES)
  end
end
