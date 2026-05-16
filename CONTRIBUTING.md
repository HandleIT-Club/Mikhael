# Contribuir a Mikhael

Mikhael es un asistente personal de IA — pensado para correr en local, en
casa o en un homelab. Cualquier mejora es bienvenida.

## Setup local

```bash
git clone https://github.com/tu-usuario/mikhael.git
cd mikhael
bundle install
cp .env.example .env                    # mínimo: GROQ_API_KEY (gratuito)
bin/rails db:prepare                    # crea las 4 DBs (primary + queue + cache + cable)
bin/rails users:create EMAIL=tu@email.com PASSWORD=elegi_uno_de_12_chars
#                                       ⤴ imprime el api_token: guardalo en .env
#                                         como MIKHAEL_API_TOKEN
bin/dev                                 # web + tailwind + solid_queue jobs
```

Abrí <http://localhost:3000>, logueate, y listo. El CLI en `bin/mikhael` usa
el mismo `MIKHAEL_API_TOKEN`.

Para vincular Telegram: setea `TELEGRAM_BOT_TOKEN` en `.env`, andá a
`/settings` (admin) y vinculá tu `telegram_chat_id`. `bin/dev` ya arranca el
polling vía `config/recurring.yml`.

## Qué tiene que pasar antes de abrir un PR

```bash
bundle exec rspec                       # suite verde
bundle exec rubocop                     # sin ofensas
bundle exec brakeman -q                 # sin warnings
```

### Tests

Todo cambio de comportamiento requiere tests. La estructura sigue el árbol
del código:

| Cambio en…               | Spec en…                       |
|--------------------------|--------------------------------|
| `app/models/`            | `spec/models/`                 |
| `app/operations/`        | `spec/operations/`             |
| `app/services/`          | `spec/services/`               |
| `app/controllers/`       | `spec/requests/`               |
| Flujo end-to-end (HTML)  | `spec/system/` (Cuprite headless) |

Helpers útiles:

- `spec/support/ai_provider_stubs.rb` → `stub_ai_provider!` mockea
  `ModelSelector` para que tests sin `GROQ_API_KEY` corran determinístico.
- `spec/support/authentication_helpers.rb` → `sign_in_as(user)` (request)
  y `sign_in_through_form(user)` (system).

### Estilo y commits

- RuboCop omakase del proyecto (`.rubocop.yml`).
- Sin `binding.pry`, `puts` de debug ni código comentado en el diff.
- Commits descriptivos. Inglés o español, lo que prefieras.
- **No mergeés con `--no-verify`**: si un hook falla, arreglá el problema.

### Seguridad

- No incluyas API keys ni tokens en el código ni en los tests.
- Si encontrás una vulnerabilidad, **no abras un issue público** —
  escribime directamente.

## Arquitectura — mapa mental

```
Web/Telegram/CLI
       │
       ▼
ProcessUserMessage (operation)        ← orquesta un turno completo
   │   │   │
   │   │   └── ChatBroadcaster        ← Turbo Streams (web)
   │   │       o NullChatBroadcaster  ← para API / specs
   │   │
   │   ├── CommandRouter              ← /dispositivos, /zona, etc.
   │   ├── MessageIntentRouter        ← "qué hora es" → Rails responde
   │   └── CreateMessage              ← llama al AI con streaming
   │              │
   │              ▼
   │         Ai::Dispatcher  ──▶  Ai::*Client (Groq/Cerebras/SambaNova/Ollama)
   │              │
   │              └── Ai::FallbackChain ← orden cuando uno falla
   │                       │
   │                       ├── Ai::ModelRegistry  ← catálogo (cached)
   │                       └── Ai::Cooldown       ← rate-limited cache
   │
   └── ToolCallExecutor               ← AI sugiere, Rails ejecuta
         │
         ├── DispatchAction           ← decide acción para un Device
         │      │
         │      ▼
         │   MqttPublisher            ← push al ESP32 vía MQTT
         │
         └── Reminder.create + ExecuteReminderJob (programado)
```

**Principio central:** *El AI sugiere, Rails ejecuta.* Los routers
determinísticos (`CommandRouter`, `MessageIntentRouter`) interceptan todo
lo que Rails puede responder sin el AI. El AI solo decide cuando no hay
respuesta exacta — y aún así, lo que ejecuta son tools en Ruby
(`ToolCallExecutor`), no el modelo.

### Capas que tocan más seguido

- `app/operations/process_user_message.rb` — un turno completo de chat.
- `app/services/assistant_context.rb` — el system prompt (incluye el
  preamble editable desde `/settings`).
- `app/services/tool_call_executor.rb` — qué hacer con la respuesta del AI.
- `app/services/ai/` — providers AI y fallback chain.
- `app/controllers/settings_controller.rb` + `users_controller.rb` —
  config admin-only.

## Qué entra y qué no en el scope

✅ **Sí:**
- Nuevos providers de IA (compatibles con OpenAI o vía RubyLLM)
- Mejoras al fallback / cooldown
- Nuevos tipos de devices o tools
- Más superficies (CLI, Telegram, web ya cubiertas)
- Corrección de bugs con test incluido
- Mejoras de docs y ejemplos

❌ **No:**
- Funcionalidades que requieran exponer Mikhael a internet pública
  (Mikhael es server privado por diseño — `config.hosts` defaultea cerrado).
- Multi-tenancy / SaaS — es asistente personal/familiar, no plataforma.
- Dependencias pesadas sin justificación clara.

## Proceso de revisión

- Los PRs se revisan tan pronto como sea posible.
- Si un PR queda 7+ días sin actividad tras feedback, puede cerrarse.
- Merge con **squash** para mantener el historial limpio.

---

Cualquier duda, abrí un [issue](https://github.com/nicolassnavarro/mikhael/issues).
