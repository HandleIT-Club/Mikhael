namespace :mikhael do
  desc "Instala todo lo necesario para correr Mikhael: Ollama, modelos y CLI"
  task install: :environment do
    puts
    puts bold("╔══════════════════════════════════════╗")
    puts bold("║") + gold("      Instalador de Mikhael           ") + bold("║")
    puts bold("╚══════════════════════════════════════╝")
    puts

    check_ollama
    pull_ollama_models
    setup_env
    install_cli
    setup_database

    puts
    puts green("✓ Instalación completa.")
    puts cyan("  Iniciá el servidor con: bin/dev")
    puts cyan("  O usá el CLI con:       mikhael")
    puts
  end

  desc "Descarga los modelos de Ollama instalados localmente"
  task pull_models: :environment do
    pull_ollama_models
  end

  private

  def check_ollama
    step("Verificando Ollama")

    if system("which ollama > /dev/null 2>&1")
      version = `ollama --version 2>/dev/null`.strip
      puts green("  ✓ Ollama instalado (#{version})")
    else
      puts yellow("  ⚠ Ollama no está instalado.")
      puts
      puts "  Instalalo con Homebrew:"
      puts cyan("    brew install ollama")
      puts
      puts "  O descargá la app desde:"
      puts cyan("    https://ollama.com/download")
      puts
      abort red("  Instalá Ollama y volvé a correr este task.")
    end
  end

  def pull_ollama_models
    step("Descargando modelos de Ollama")

    ollama_models = OllamaModels.installed

    if ollama_models.empty?
      puts yellow("  ⚠ No se detectaron modelos instalados. Instalá alguno con: ollama pull <modelo>")
      return
    end

    ollama_models.each do |model|
      puts "  → #{model}"
      if system("ollama pull #{model}")
        puts green("    ✓ Listo")
      else
        puts red("    ✗ Falló — podés intentarlo después con: ollama pull #{model}")
      end
    end
  end

  def setup_env
    step("Configurando .env")

    env_path = Rails.root.join(".env")

    if env_path.exist?
      puts yellow("  ⚠ Ya existe un .env, no se sobreescribe.")
      return
    end

    example = Rails.root.join(".env.example")
    if example.exist?
      FileUtils.cp(example, env_path)
      puts green("  ✓ .env creado desde .env.example")
    else
      File.write(env_path, <<~ENV)
        GROQ_API_KEY=tu_api_key_de_groq
        OLLAMA_URL=http://localhost:11434/v1/
        MIKHAEL_URL=http://localhost:3000
      ENV
      puts green("  ✓ .env creado")
    end

    puts yellow("  → Editá .env y agregá tu GROQ_API_KEY para usar modelos en la nube.")
  end

  def setup_database
    step("Configurando base de datos")
    Rake::Task["db:prepare"].invoke
    puts green("  ✓ Base de datos lista")
  end

  def install_cli
    step("Instalando CLI de Mikhael")

    cli_source = Rails.root.join("bin", "mikhael")

    unless cli_source.exist?
      puts yellow("  ⚠ No se encontró bin/mikhael en el proyecto, omitiendo.")
      return
    end

    candidates = [
      File.expand_path("~/.local/bin/mikhael"),
      "/usr/local/bin/mikhael"
    ]

    install_path = candidates.find { |p| File.writable?(File.dirname(p)) }

    unless install_path
      puts yellow("  ⚠ No se encontró un directorio escribible en el PATH.")
      puts "  Copialo manualmente con:"
      puts cyan("    cp #{cli_source} /usr/local/bin/mikhael && chmod +x /usr/local/bin/mikhael")
      return
    end

    FileUtils.cp(cli_source, install_path)
    FileUtils.chmod(0o755, install_path)
    puts green("  ✓ CLI instalado en #{install_path}")

    shell_rc = detect_shell_rc
    alias_line = 'alias Mikhael="mikhael"'

    if shell_rc && !File.read(shell_rc).include?(alias_line)
      File.open(shell_rc, "a") { |f| f.puts "\n#{alias_line}" }
      puts green("  ✓ Alias 'Mikhael' agregado en #{shell_rc}")
      puts yellow("  → Recargá tu shell con: source #{shell_rc}")
    end
  end

  def detect_shell_rc
    shell = ENV["SHELL"].to_s
    if shell.include?("zsh")
      File.expand_path("~/.zshrc")
    elsif shell.include?("bash")
      File.expand_path("~/.bashrc")
    end
  end

  # ─── Helpers de output ────────────────────────────────────────────────────

  def step(msg)
    puts bold("▸ #{msg}...")
  end

  def green(s)  = "\033[0;32m#{s}\033[0m"
  def yellow(s) = "\033[1;33m#{s}\033[0m"
  def cyan(s)   = "\033[0;36m#{s}\033[0m"
  def red(s)    = "\033[0;31m#{s}\033[0m"
  def bold(s)   = "\033[1m#{s}\033[0m"
  def gold(s)   = "\033[1;38;5;220m#{s}\033[0m"
end
