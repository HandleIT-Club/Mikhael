<div align="center">

<pre>
╔══════════════════════════════════════╗
║           M I K H A E L              ║
╚══════════════════════════════════════╝
</pre>

### *«¿Quién como Dios?»*

**Tu asistente de IA personal — corriendo en tu propia máquina.**

Mikhael es un asistente que vive en tu LAN. Chateás desde la web, la
terminal o Telegram, y le da órdenes reales a tus **microcontroladores**
(ESP32, Arduino, Raspberry Pi) — *"iniciá el riego"* abre una válvula
real. Usa modelos cloud gratuitos (Groq, Cerebras, SambaNova) con fallback
automático, o **100% offline** con Ollama.

![Ruby](https://img.shields.io/badge/Ruby-3.4-CC342D?style=flat-square&logo=ruby&logoColor=white)
![Rails](https://img.shields.io/badge/Rails-8.1-D30001?style=flat-square&logo=rubyonrails&logoColor=white)
![Hotwire](https://img.shields.io/badge/Hotwire-Turbo-8b5cf6?style=flat-square)
![Telegram](https://img.shields.io/badge/Telegram-Bot-26A5E4?style=flat-square&logo=telegram&logoColor=white)
![MQTT](https://img.shields.io/badge/MQTT-IoT-660066?style=flat-square)
![Tests](https://img.shields.io/badge/Tests-359%20passing-22c55e?style=flat-square)
![License](https://img.shields.io/badge/Licencia-AGPL--3.0-blue?style=flat-square)

</div>

---

## ¿Qué es Mikhael?

Asistente de IA personal que corrés en **tu propia máquina** o **homelab**.
No depende de servicios cloud privativos: vos sos dueño de tus datos, de
tus conversaciones y del control de tus dispositivos físicos.

### Cuatro formas de hablarle

| Cliente | Para qué sirve |
|---------|----------------|
| 🌐 **Web** (Hotwire + Turbo) | Chat principal, gestión de modelos y devices, configuración admin |
| 🖥️ **CLI** (`bin/mikhael`) | Mismo chat desde la terminal, con modo agente que detecta y ejecuta comandos shell |
| 💬 **Telegram** | Chat + comandos desde el celu, esté donde estés |
| 📡 **API HTTP** | Endpoint para microcontroladores (ESP32, Arduino) que devuelve JSON con acciones |

Todos contra el mismo backend Rails. Una conversación de la web aparece en
el CLI; un comando por Telegram dispara una acción en el ESP32 vía MQTT.

#### 🎤 Entrada por voz en Telegram

Mandás una nota de voz al bot → Whisper (Groq) la transcribe → el texto
entra al pipeline como si lo hubieras escrito.

**Límite gratuito de Groq Whisper:** 2 000 req/día · 28 800 s de audio/día.
Si se alcanza el límite, Mikhael te avisa. No hay fallback a otro proveedor
(solo Groq ofrece Whisper gratuito).

Requiere `GROQ_API_KEY` — la misma que ya usás para los modelos de chat.

### Lo que podés hacer con tus microcontroladores

Cargás un dispositivo (*"ESP32 Riego"*) con su lista de acciones
(`open_valve`, `close_valve`, etc.). A partir de ahí:

- 🤖 El **ESP32 le pregunta a Mikhael** con datos de sensores: *"humedad 18%,
  temperatura 32°C"* → recibe `{action: "open_valve", value: 30}` y abre 30 min
- 👤 **Vos comandás desde Telegram**: *"iniciá el riego"* → Mikhael interpreta,
  decide la acción y se la **empuja por MQTT** al ESP32
- 📲 Mikhael te **avisa por Telegram** cuando un dispositivo ejecuta algo importante

---

## Features

- 🔁 **Fallback automático** entre providers (Groq → Cerebras → SambaNova → Ollama)
- 🌊 **Streaming** token a token en web y CLI
- 🛠️ **Tools en Ruby**: el AI sugiere `call_device` / `create_reminder`, Rails los ejecuta
- ⏰ **Recordatorios programados** con notificación a Telegram
- 👥 **Multi-usuario** con auth real (email + password, brute-force protection)
- 🔐 **Admin-only** para devices, contexto del asistente y gestión de cuentas
- 📡 **MQTT push** opcional a microcontroladores
- 🧪 **288 tests** (RSpec + Capybara + Cuprite headless), 0 warnings de Brakeman

---

## Stack

Rails 8.1 · Hotwire (Turbo + Stimulus) · Tailwind CSS v4 · SQLite ·
Solid trio (Cache, Queue, Cable) · dry-monads · Faraday · RubyLLM · MQTT.

---

## Quickstart

### Camino más fácil: Docker

Si tenés Docker instalado, este es el camino más corto — no necesitás
Ruby, Rails, ni SQLite en tu máquina:

```bash
git clone https://github.com/tu-usuario/mikhael.git
cd mikhael
cp .env.example .env                              # editá: poné tu GROQ_API_KEY
docker compose up -d                              # primera vez: build (~2-3 min)
```

Abrí <http://localhost:7777> → el wizard te lleva a `/setup` para crear el
primer admin. Listo.

> Puerto 7777 (cuádruple siete: perfección divina × 4), elegido para no
> chocar con el `:3000` típico de Rails dev.

Comandos útiles:

```bash
docker compose logs -f                            # ver logs en vivo
docker compose down                               # apagar (datos persisten)
docker compose exec web bin/rails users:create \  # crear más admins
  EMAIL=otro@ejemplo.com PASSWORD=algo_de_12_chars_min
```

### Alternativa: instalación local (sin Docker)

```bash
git clone https://github.com/tu-usuario/mikhael.git
cd mikhael
bundle install
cp .env.example .env                              # mínimo: GROQ_API_KEY
# Ojo: cambiá MIKHAEL_URL a http://localhost:3000 (default de bin/dev)
bin/rails db:prepare                              # crea las 4 DBs (primary + queue + cache + cable)
bin/rails users:create EMAIL=tu@mail.com PASSWORD=algo_de_12_chars_min
#                                       ⤴ imprime tu API token — guardalo
bin/dev                                           # web + tailwind + jobs
```

> **¿Venís de una versión anterior con una sola DB?** Corré `bin/rails db:prepare`
> para crear las DBs nuevas (`development_queue.sqlite3`, `_cache`, `_cable`)
> sin tocar tu primary. Las tablas de SolidQueue/Cache/Cable viven ahora en
> archivos separados (mismo pattern que producción).

Abrí <http://localhost:3000>. Logueate. Listo.

Si querés el CLI: pegá el API token impreso al `.env` como `MIKHAEL_API_TOKEN`
y corré `bin/mikhael`.

### Prerrequisitos

- Ruby 3.4+ (rbenv/asdf/mise recomendado)
- SQLite (viene con macOS; `apt install libsqlite3-dev` en Debian/Ubuntu)
- Al menos una API key gratuita — **Groq** es la más generosa: <https://console.groq.com>

### Opcionales

| Componente | Cuándo | Setup |
|------------|--------|-------|
| **Ollama** | Modelos locales offline | `brew install ollama && ollama pull llama3.2:3b` |
| **Mosquitto** (MQTT) | Empujar comandos a ESP32 | `brew install mosquitto` + setear `MQTT_URL` |
| **Bot de Telegram** | Chat desde el celu | Token via [@BotFather](https://t.me/BotFather) → `.env` |

---

## Las superficies

### 🌐 Web — `http://localhost:3000`

- **Chat** con sidebar de conversaciones, model selector, streaming en vivo
- **`/devices`** — CRUD de microcontroladores, panel de comando directo, tokens
- **`/settings`** (admin) — contexto del asistente + gestión de cuentas

### 🖥️ CLI — `bin/mikhael`

Chat completo + menú de devices + modo agente:

```bash
mikhael       # modo chat normal con streaming
mikhael -a    # modo agente: detecta bloques ```bash```  en la respuesta
              # y te pregunta antes de ejecutarlos
```

Comandos durante el chat: `dispositivos`, `convs`, `limpiar`, `abrir`, `salir`.

### 💬 Telegram

Token vía [@BotFather](https://t.me/BotFather). Lo seteás en `.env`:

```env
TELEGRAM_BOT_TOKEN=123456:ABC-DEF...
```

`bin/dev` arranca el polling automáticamente. Vinculá tu `chat_id` desde
`/settings` (o pasalo al crear el user con `TELEGRAM_CHAT_ID=...`).

Slash commands disponibles: `/start`, `/dispositivos`, `/recordatorios`,
`/borrar_recordatorio N`, `/zona`, `/reset`.

### 📡 Microcontroladores

Cargás un device con `bin/mikhael` o desde `/devices` (web). Te da un token
único. El ESP32 puede operar en dos modos:

**Modo reactivo (pull)** — el device le pregunta a Mikhael:

```cpp
// pseudo-código ESP32 — POST /api/v1/action con Bearer <token>
http.POST("{\"context\":\"humedad: 18%, temperatura: 32°C\"}");
// Respuesta: {"action": "open_valve", "value": 30, "reason": "..."}
```

**Modo push (MQTT)** — el device se suscribe a `mikhael/devices/<id>/command`
y Mikhael publica ahí cuando vos le hablás desde la web/CLI/Telegram.

Ejemplos completos para Arduino C++ y MicroPython están en el código de
tests / firmware del proyecto.

---

## Configuración (`.env`)

Solo lo mínimo es obligatorio. El resto es opt-in.

```env
# ─── Mínimo ─────────────────────────────────────────────────────
GROQ_API_KEY=tu_key                # gratis en https://console.groq.com
MIKHAEL_URL=http://localhost:3000  # para el CLI

# ─── API token del CLI (se imprime al crear el user) ────────────
MIKHAEL_API_TOKEN=...

# ─── Más providers (cualquiera funciona en fallback) ────────────
# CEREBRAS_API_KEY=...
# SAMBANOVA_API_KEY=...
# OLLAMA_URL=http://localhost:11434/v1/

# ─── Telegram (opcional pero recomendado) ───────────────────────
# TELEGRAM_BOT_TOKEN=123456:ABC-DEF...

# ─── MQTT push para devices (opcional) ──────────────────────────
# MQTT_URL=mqtt://user:pass@localhost:1883

# ─── Misc ───────────────────────────────────────────────────────
# MIKHAEL_TZ=Buenos Aires                # fallback (web autodetecta)
# RATE_LIMIT_LOGIN_PER_MIN=5             # brute-force protection
# MIKHAEL_HOSTS=mikhael.local,...        # solo si deployás
```

---

## Referencia de API

Todas las rutas (excepto `/api/v1/action` y `/api/v1/heartbeat`) exigen
`Authorization: Bearer <api_token>` del user.

```
GET    /api/v1/models                              # lista modelos disponibles
GET    /api/v1/conversations                       # lista conversaciones (del user)
GET    /api/v1/conversations/:id                   # conversación + mensajes
POST   /api/v1/conversations                       # crear
DELETE /api/v1/conversations/:id                   # eliminar
POST   /api/v1/conversations/:id/messages          # mandar mensaje (sin streaming)
POST   /api/v1/conversations/:id/messages/stream   # mandar mensaje (SSE streaming)

GET    /api/v1/devices                             # admin-only
POST   /api/v1/devices                             # admin-only — devuelve token
PATCH  /api/v1/devices/:id                         # admin-only
DELETE /api/v1/devices/:id                         # admin-only
POST   /api/v1/devices/:id/regenerate_token        # admin-only
POST   /api/v1/devices/:id/command                 # admin-only — comando NL → MQTT push

POST   /api/v1/action                              # device → Mikhael (Bearer device.token)
POST   /api/v1/heartbeat                           # device → ping (Bearer device.token)
```

### Rate limits

429 con `Retry-After` header y `{ "error": "rate_limit_exceeded", "retry_after": 30 }`.
Contadores en SolidCache (compartidos entre procesos).

| Endpoint | Default | Por |
|----------|---------|-----|
| `POST /api/v1/action` | 60/min | Token del device |
| `POST /messages` y `stream` | 30/min | User ID |
| `POST /devices/:id/command` | 30/min | IP |
| Rutas web | 100/min | User ID (logueado) o IP |
| `POST /session` (login) | 5/min | IP |

---

## Arquitectura

```
Web · Telegram · CLI
       │
       ▼
ProcessUserMessage (operation)        ← orquesta un turno completo
   ├── CommandRouter                  ← /dispositivos, /zona, /recordatorios…
   ├── MessageIntentRouter            ← "qué hora es" → Rails responde
   ├── CreateMessage  ──▶  Ai::Dispatcher ──▶ Ai::*Client (Groq/Cerebras/…)
   │                              │
   │                              └── Ai::FallbackChain (orden + Cooldown)
   │                                          │
   │                                          └── Ai::ModelRegistry
   └── ToolCallExecutor               ← AI sugiere, Rails ejecuta
         ├── DispatchAction → MqttPublisher → ESP32
         └── Reminder + ExecuteReminderJob
```

### Decisiones de diseño

- **AI sugiere, Rails ejecuta.** Los routers determinísticos interceptan
  todo lo que Rails puede responder sin AI. Cuando el AI sí responde, lo
  que ejecuta acciones son **tools en Ruby**, no el modelo.
- **Una sola fuente del prompt.** `AssistantContext` lo arma combinando el
  *preamble* editable (en `Setting`) + REGLAS críticas inmutables en código
  + tools + lista actual de devices. Web, Telegram y CLI usan el mismo.
- **Fallback transparente.** Si Groq devuelve 429, Mikhael salta a
  Cerebras → SambaNova → Ollama sin que el user note. Cooldown
  por modelo en cache distribuido.
- **Server privado por diseño.** No hay signup público; los users los
  crea el admin. Devices y configuración son admin-only. `config.hosts`
  rechaza todo por default — hay que listar el host explícitamente.

---

## Seguridad

- **Auth multi-user** con `bcrypt`, `reset_session` antes de login (anti-fixation),
  mensajes genéricos (anti-enumeration), rate limit en login.
- **API tokens** guardados como HMAC-SHA256 digest. El plain solo existe en
  memoria al crearlos/regenerarlos. Lookup determinístico vía índice unique.
- **CSRF** estándar de Rails en toda ruta web. CSP defaultea cerrado en prod.
- **Output del AI sanitizado** con allowlist explícita (filter_html + sanitize)
  para cerrar prompt injection que escupa `<script>`.
- **Devices admin-only** — los tokens de los devices son separados de los
  user tokens, no se mezclan.

Si encontrás una vulnerabilidad, **no abras un issue público** — escribime
directamente.

---

## Tests

```bash
bundle exec rspec                      # 288 examples, 0 failures
bundle exec rspec spec/system          # solo browser tests (Cuprite headless)
bundle exec brakeman -q                # 0 warnings
```

Cobertura:

- **Unit** (services, models, jobs, operations)
- **Request** (sessions, API JSON, web controllers, rate limiting)
- **System** (Capybara + Cuprite — login, slash commands, tool execution,
  scoping cross-user) — no mockean al user, tipean en el form real

---

## Roadmap

| Idea | Notas |
|------|-------|
| Bridge BLE | Daemon Python que traduce GATT ↔ HTTP local |
| Memoria entre conversaciones | Embeddings + recuperación contextual |
| Whisper local | Entrada por voz desde el CLI o devices |
| Bot Telegram con voice notes | Transcripción on-device |

---

## Contribuir

Ver [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Licencia

**AGPL-3.0** — ver [LICENSE](LICENSE). Copyright (C) 2026 Nicolás S. Navarro.

Copyleft: si modificás Mikhael y lo ofrecés como servicio en red, tu código
modificado tiene que estar disponible. Para uso personal, hacé lo que quieras.

---

<div align="center">

Construido con ☕ por alguien que claramente tiene **muy** pocas horas libres.

</div>
