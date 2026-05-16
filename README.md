<div align="center">

<pre>
╔══════════════════════════════════════╗
║           M I K H A E L              ║
╚══════════════════════════════════════╝
</pre>

### *«¿Quién como Dios?»*

**Tu asistente de IA personal — corriendo en tu propia máquina.**

Mikhael te deja chatear con LLMs desde el navegador, la terminal o **Telegram**. Y va más
allá del chat: integra tus **microcontroladores** (ESP32, Arduino, Raspberry Pi) para que
puedas decirle *"iniciá el riego"* y abra una válvula real, o *"abrí la puerta"* y mueva un
servo. Funciona con **modelos gratuitos en la nube** (Groq, Cerebras, SambaNova) con
fallback automático entre proveedores, o **completamente offline** con Ollama.

![Ruby](https://img.shields.io/badge/Ruby-3.4.2-CC342D?style=flat-square&logo=ruby&logoColor=white)
![Rails](https://img.shields.io/badge/Rails-8.1-D30001?style=flat-square&logo=rubyonrails&logoColor=white)
![Hotwire](https://img.shields.io/badge/Hotwire-Turbo-8b5cf6?style=flat-square)
![Telegram](https://img.shields.io/badge/Telegram-Bot-26A5E4?style=flat-square&logo=telegram&logoColor=white)
![MQTT](https://img.shields.io/badge/MQTT-IoT-660066?style=flat-square)
![Tests](https://img.shields.io/badge/Tests-240%20passing-22c55e?style=flat-square)
![License](https://img.shields.io/badge/Licencia-AGPL--3.0-blue?style=flat-square)

</div>

---

## ¿Qué es Mikhael?

Mikhael es un asistente de IA personal que corrés **en tu propia máquina**. No depende de
servicios cloud privativos: vos sos dueño de tus datos, de tus conversaciones y del control
de tus dispositivos físicos.

### Cuatro formas de hablarle

| Cliente | Para qué sirve |
|---------|----------------|
| 🌐 **Web** (Hotwire + Turbo) | Chat principal, gestión de modelos, gestión de microcontroladores |
| 🖥️ **CLI** (`bin/mikhael`) | Mismo chat desde la terminal, con modo agente que detecta y ejecuta comandos shell |
| 💬 **Telegram** | Chateá con Mikhael y comandá tus dispositivos desde el celular, esté donde estés |
| 📡 **API HTTP** | Endpoint para microcontroladores (ESP32, Arduino, etc.) que devuelve JSON con acciones |

Los cuatro conviven contra el mismo backend Rails. Una conversación creada en el browser
aparece en el CLI; un comando que mandás por Telegram dispara una acción en tu ESP32 vía MQTT.

### Lo que podés hacer con tus microcontroladores

Cargás un dispositivo en Mikhael (por ejemplo *"ESP32 Riego"*) con su lista de acciones
(`open_valve`, `close_valve`, etc.). A partir de ahí:

- 🤖 El **ESP32 le pregunta a Mikhael** con datos de sensores: *"humedad 18%, temperatura 32°C"* → recibe `{action: "open_valve", value: 30}` y abre la válvula 30 minutos
- 👤 **Vos comandás desde Telegram**: *"iniciá el riego"* → Mikhael interpreta, decide la acción y se la **empuja por MQTT** al ESP32 — sin tocar el código del dispositivo
- 📲 Mikhael te **avisa por Telegram** cuando un dispositivo ejecuta una acción importante

---

## Features

- **Multi-provider con fallback automático**: Groq → Cerebras → SambaNova → Ollama. Si un
  modelo se queda sin cuota, Mikhael salta al siguiente sin interrumpir la conversación.
  La cadena se construye dinámicamente: providers sin API key configurada se filtran
  automáticamente, no se intenta llamarlos.
- **Bot de Telegram opcional**: chateá con Mikhael desde el celular y comandá tus
  dispositivos en lenguaje natural. Mikhael conoce tus devices y los activa por vos. Mikhael
  hace polling a Telegram, no necesitás exponer nada a internet.
- **Microcontroladores con acciones propias**: cada device define su rol y la lista exacta
  de funciones que su firmware implementa. El AI queda constrained a devolver solo esas
  acciones — sin inventarse nombres.
- **Dos modos de integración con devices**: el device puede llamar a Mikhael con datos de
  sensor (modo reactivo HTTP), o Mikhael puede empujar comandos al device vía **MQTT** cuando
  alguien emite una orden desde browser, CLI o Telegram (modo push).
- **System prompts editables por modelo**: cada modelo tiene su personalidad/contexto
  configurable desde la UI (`/model_configs`).
- **Detección dinámica de modelos Ollama**: si instalás un modelo nuevo con
  `ollama pull <modelo>`, aparece automáticamente en el selector — sin reiniciar nada.
- **Output JSON estructurado** para los devices, con retry y parsing robusto frente a LLMs
  que se desvían del esquema.
- **Modo agente en el CLI**: Mikhael propone comandos shell y los ejecuta con tu confirmación,
  para que lo uses como pair programmer en la terminal.
- **Multi-user con autenticación real**: cada miembro de la familia tiene su email + password,
  sus propias conversaciones, recordatorios y zona horaria. Los dispositivos IoT son
  compartidos (hogar). Sin signup público — solo el admin crea cuentas vía CLI. Brute-force
  protection en el login, secure session cookies, scoping estricto entre users.
- **API token por user**: cada user tiene su `api_token` (256-bit, regenerable). El CLI y
  apps externas autentican con `Authorization: Bearer <token>`. Tokens de Device (para
  ESP32) siguen siendo independientes.
- **AGPL-3.0**: software libre, copyleft.

---

## Stack

| | |
|---|---|
| 🛤️ **Rails 8.1** | Backend monolítico, Action Cable, Solid Queue/Cache |
| ⚡ **Hotwire** (Turbo + Stimulus) | UI reactiva sin framework JS |
| 🎨 **Tailwind CSS v4** | Estilos oscuros, sin design system propio |
| 🗄️ **SQLite** | Una base por host. Suficiente para uso personal y miles de devices |
| 🤖 **RubyLLM** + `Net::HTTP` | Abstracción para Ollama/Groq; HTTP plano para Cerebras/SambaNova |
| 🧱 **dry-monads** | Manejo de errores funcional (`Success`/`Failure`) en operations |

---

## Providers y modelos

Mikhael soporta 4 proveedores de IA en paralelo, con prioridad y fallback automático:

```
Groq avanzado → Groq intermedio → Groq básico →
Cerebras avanzado → Cerebras básico →
SambaNova avanzado → SambaNova básico →
Ollama (lo que tengas instalado localmente)
```

| Provider | Variable de entorno | Tier | Modelos |
|---|---|---|---|
| **Groq** | `GROQ_API_KEY` | Avanzado | `llama-3.3-70b-versatile`, `llama-4-scout`, `gpt-oss-120b` |
| **Groq** | ↑ | Intermedio | `qwen3-32b`, `gpt-oss-20b` |
| **Groq** | ↑ | Básico | `llama-3.1-8b-instant`, `allam-2-7b` |
| **Cerebras** | `CEREBRAS_API_KEY` | Avanzado/Básico | `llama-3.3-70b`, `llama3.1-8b` |
| **SambaNova** | `SAMBANOVA_API_KEY` | Avanzado/Básico | `Llama-3.3-70B`, `Llama-3.1-405B`, `Llama-3.1-8B` |
| **Ollama** | — (local) | Dinámico | Cualquier modelo que tengas `ollama pull`-eado |

> 💡 **Para empezar sin pagar nada**: con solo `GROQ_API_KEY` (tier gratuito generoso) Mikhael
> ya funciona completo. Ollama es opcional.

---

## Upgrading desde la versión single-user

Si venís de la versión vieja (sin users), Mikhael ahora es multi-user. La estructura de
datos cambió de raíz: `conversations`, `reminders` y algunos `settings` ahora pertenecen
a un user. **No hay migración automática** — pasos del upgrade:

```bash
git pull
bundle install
bin/rails db:drop db:create db:migrate
bin/rails users:create EMAIL=tu@email.com PASSWORD=algo_de_12_chars
```

Si querés que ese user reciba los mensajes del bot de Telegram:

```bash
bin/rails users:create EMAIL=tu@email.com PASSWORD=algo_de_12_chars TELEGRAM_CHAT_ID=tu_chat_id
```

El comando imprime el `api_token` — pegalo en tu `~/.mikhaelrc` o donde tengas la config
del CLI.

`MIKHAEL_PASSWORD` ya no existe. Login es por email/password con session cookie en web,
o `Authorization: Bearer <api_token>` en API.

---

## Instalación

Lo mínimo que necesitás es **Ruby 3.4.2** y una **API key gratuita de Groq**. Todo lo demás
(Ollama, Mosquitto para MQTT, Telegram) es opcional y lo podés sumar después.

### 1) Lo básico — necesario sí o sí

#### Ruby 3.4.2

```bash
# macOS — instalar rbenv si no lo tenés
brew install rbenv ruby-build
rbenv init                       # seguí las instrucciones que imprime

# Linux (Ubuntu/Debian)
sudo apt install rbenv

# Después, en cualquier sistema:
rbenv install 3.4.2
rbenv global 3.4.2
ruby -v                          # debería decir 3.4.2
```

#### SQLite (ya viene incluido en macOS, en Linux):

```bash
sudo apt install sqlite3 libsqlite3-dev
```

#### Una API key gratuita

Andá a **[console.groq.com](https://console.groq.com)**, creá cuenta (gratis, sin tarjeta),
generá una API key y guardala. La vamos a usar en un toque.

#### Cloná Mikhael, instalá, creá tu user

```bash
git clone https://github.com/HandleIT-Club/Mikhael.git
cd Mikhael
bundle install
cp .env.example .env
bin/rails db:prepare

# Bootstrap: creá tu user admin (signup público no existe, todo va por consola)
bin/rails users:create EMAIL=tu@email.com PASSWORD=algo_de_12_chars_mínimo
```

El último comando imprime tu `api_token` — guardalo, lo necesita el CLI para
autenticar (`Authorization: Bearer <token>`).

Abrí el archivo `.env` y pegá tu API key de Groq:

```env
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxx
```

¡Listo! Arrancá con `bin/dev`, abrí [http://localhost:3000](http://localhost:3000) y logueate.

### 2) Comando `mikhael` en tu terminal (recomendado)

```bash
bin/rails mikhael:install
```

Eso instala los comandos `mikhael` y `Mikhael` en tu `PATH`. Después podés correrlo desde
cualquier directorio.

### 3) Ollama — modelos locales offline (opcional)

Si querés correr modelos completamente locales (sin internet, sin API keys, datos 100%
privados):

```bash
# Instalación
# macOS / Linux: descargar desde https://ollama.com/download
# o con homebrew:
brew install ollama

# Descargá modelos (cualquiera, Mikhael los detecta solos)
ollama pull llama3.2:3b           # liviano, anda en cualquier máquina
ollama pull qwen2.5-coder:7b      # bueno para código
ollama pull mistral:7b            # generalista
```

Mikhael los muestra automáticamente en el selector de modelos. No hace falta reiniciar nada.

### 4) Mosquitto — broker MQTT (opcional, solo si vas a usar microcontroladores en modo push)

Mosquitto es un servidor MQTT gratuito. Permite que Mikhael **empuje comandos** a tus
ESP32 cuando vos le pedís algo desde el browser, CLI o Telegram.

```bash
# macOS
brew install mosquitto
brew services start mosquitto

# Linux (Ubuntu/Debian)
sudo apt install mosquitto mosquitto-clients
sudo systemctl enable --now mosquitto
```

Verificá que esté corriendo:

```bash
mosquitto_sub -h localhost -t test &
mosquitto_pub -h localhost -t test -m "hola"
# Deberías ver "hola" en el subscriber
```

Agregá al `.env` de Mikhael:

```env
MQTT_URL=mqtt://localhost:1883
```

Reiniciá `bin/dev` y listo. Tus dispositivos ahora pueden suscribirse a
`mikhael/devices/<device_id>/command`.

### 5) Bot de Telegram (opcional, súper recomendado)

Ver la sección completa más abajo: [**Uso 4 — Bot de Telegram**](#uso-4--bot-de-telegram).

---

## Configuración (`.env`)

Solo `GROQ_API_KEY` es obligatoria. El resto es opcional según qué features quieras usar.

```env
# ─── IA (al menos una API key, Groq es la recomendada) ───
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxx
CEREBRAS_API_KEY=                          # opcional
SAMBANOVA_API_KEY=                         # opcional
OLLAMA_URL=http://localhost:11434/v1/      # opcional, modelos locales

# ─── Servidor ───
MIKHAEL_URL=http://localhost:3000          # la usan el CLI y los devices

# ─── MQTT (opcional, para empujar comandos a microcontroladores) ───
MQTT_URL=mqtt://localhost:1883

# ─── Telegram bot (opcional, para chat y comandos desde el celu) ───
# TELEGRAM_BOT_TOKEN=123456:ABC-DEF...
# TELEGRAM_CHAT_ID=987654321
# ENABLE_TELEGRAM_POLLING=true             # necesario en development

# ─── Auth para exponer Mikhael fuera de localhost (opcional) ───
# MIKHAEL_PASSWORD=algo_largo_y_random
```

---

## Uso 1 — Interfaz web

```bash
bin/dev
```

Abrí `http://localhost:3000`.

### Vistas

| Ruta | Qué hacés |
|------|-----------|
| `/` | Lista de conversaciones + modal para crear una nueva |
| `/conversations/:id` | Chat de Mikhael con Markdown y bloques de código |
| `/model_configs` | Editás el system prompt de cada modelo |
| `/devices` | Gestionás los microdispositivos: creás, regenerás token, cambiás system prompt y nivel de seguridad |

### Cosas finas

- **Fallback transparente**: si Groq se queda sin cuota mientras estás chateando, Mikhael
  cambia al siguiente modelo y la UI te avisa con un badge `↪ modelo cambiado a X`.
- **Título auto-generado**: el primer mensaje genera el título de la conversación
  automáticamente (primeras 8 palabras).
- **Memoria de conversación**: cada modelo recibe el historial completo de la conversación,
  no solo el último mensaje.

---

## Uso 2 — Cliente de terminal

```bash
mikhael           # Chat normal
mikhael -a        # Modo agente (detecta y propone comandos shell para ejecutar)
```

El CLI levanta automáticamente Ollama y Rails si no están corriendo, y los cierra al salir.

### Menú principal

```
Conversaciones recientes:
  [1] Mi proyecto Rails (groq · nube)
  [2] Notas de diseño  (ollama · local)
  [n] Nueva conversación
  [d] Gestionar dispositivos
  [o] Abrir en el navegador
  [x#] Eliminar (ej: x1, x2...)
```

### Comandos durante el chat

| Comando | Acción |
|---|---|
| `salir` / `exit` / `q` | Cerrar Mikhael y apagar servicios |
| `limpiar` / `nueva` | Empezar una conversación nueva |
| `convs` / `atras` / `back` | Volver al selector de conversaciones |
| `dispositivos` / `devices` | Abrir el menú de gestión de dispositivos |
| `open` / `abrir` | Abrir el servidor en el navegador |

### Menú de dispositivos

```
╔══ Dispositivos ═══════════════════════╗
 [1] Riego huerta (riego_01) — 🟢 normal · open_valve, close_valve
 [2] Cerradura entrada (cerradura_01) — 🔒 alta seguridad · unlock, lock
╠═══════════════════════════════════════╣
 [n] Nuevo dispositivo
 [c#] Comandar  (ej: c1)
 [e#] Editar    (ej: e1)
 [r#] Regenerar token (ej: r1)
 [x#] Eliminar  (ej: x1)
 [v] Volver al chat
╚═══════════════════════════════════════╝
```

Con `[c#]` podés enviarle un comando en lenguaje natural a cualquier dispositivo directamente
desde la terminal:

```
Opción: c1
Comandar: Riego huerta
  Mensaje: La humedad está en 18%, son las 10 de la mañana
  Enviando...
  ✓ Acción: open_valve
  Valor:    30
  Razón:    Humedad crítica por debajo del 30%. Riego de 30 min recomendado.
```

Si `MQTT_URL` está configurado, el comando también llega al dispositivo físico vía MQTT.

> ⚠️ Los tokens **solo se muestran al crear o regenerar** un dispositivo. Si lo perdés,
> regeneralo — el viejo deja de funcionar inmediatamente.

### Modo agente (`mikhael -a`)

En modo agente, cuando Mikhael responde con un bloque de código bash/shell, el CLI lo
extrae y te pregunta si querés ejecutarlo:

```
Vos: ¿cuántos archivos hay en este directorio?

Mikhael: Podés usar:
  ls | wc -l

╔══ Comando detectado ══════════════════╗
║ ls | wc -l
╚═══════════════════════════════════════╝
¿Ejecutar? [s/N]: s
      47
✓ Finalizado.

Mikhael (analizando...): Hay 47 entradas en el directorio actual.
```

Mikhael ve la salida del comando y la analiza en el siguiente turno.

---

## Uso 3 — Microdispositivos (ESP32 / Arduino / Pi)

Cualquier dispositivo con WiFi puede integrarse con Mikhael de dos formas:

| Modo | Quién inicia | Cuándo usarlo |
|------|-------------|---------------|
| **Reactivo (HTTP)** | El dispositivo llama a Mikhael con datos de sensor | El device tiene lógica propia para decidir cuándo preguntar |
| **Push (MQTT)** | Mikhael empuja comandos al dispositivo | Un humano ordena algo desde el browser o CLI |

Ambos modos pueden coexistir en el mismo dispositivo.

### Setup inicial

1. Creás el dispositivo desde `/devices` (web) o `[d]` → `[n]` en el CLI
2. Definís el **system prompt**: qué rol cumple y sus reglas de decisión
3. Definís las **acciones**: lista de nombres de función que tu firmware implementa, separadas por coma  
   → Ejemplo: `open_valve, close_valve, schedule_irrigation, alert_low_water`
4. Elegís el **nivel de seguridad** (`normal` o `high`)
5. Copiás el **token** — se muestra **una sola vez**

Las acciones que cargás en Mikhael son el contrato entre el AI y tu firmware. El AI solo
puede devolver acciones de esa lista. Tu firmware debe implementar exactamente esas funciones.

### Modo reactivo — el device llama a Mikhael

El dispositivo envía contexto (datos de sensores, estado, hora) y recibe una acción:

```
POST /api/v1/action
Authorization: Bearer <device_token>
Content-Type: application/json

{ "context": "humedad: 18%, temperatura: 28°C, hora: 07:15" }
```

**Respuesta (seguridad normal):**

```json
{
  "action": "open_valve",
  "value": 30,
  "reason": "humedad por debajo del umbral mínimo"
}
```

**Respuesta (seguridad alta):**

```json
{
  "action": "unlock",
  "value": null,
  "reason": "usuario autorizado en horario permitido",
  "requires_confirmation": true
}
```

`requires_confirmation: true` indica que el firmware debe pedir confirmación física antes
de ejecutar (botón, PIN, notificación push — lo que corresponda a tu caso de uso).

#### Ejemplo C++ (Arduino/ESP32)

```cpp
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

const char* MIKHAEL_URL  = "http://192.168.1.100:3000/api/v1/action";
const char* DEVICE_TOKEN = "tu_token_de_64_caracteres";

void askMikhael(float humidity, float temperature) {
  HTTPClient http;
  http.begin(MIKHAEL_URL);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", String("Bearer ") + DEVICE_TOKEN);

  String body = "{\"context\":\"humedad: " + String(humidity, 1) +
                "%, temperatura: " + String(temperature, 1) + "°C\"}";

  int status = http.POST(body);
  if (status == 200) {
    JsonDocument doc;
    deserializeJson(doc, http.getString());

    String action = doc["action"].as<String>();
    int    value  = doc["value"] | 0;
    bool   needs  = doc["requires_confirmation"] | false;

    if (needs) awaitUserConfirmation();

    if      (action == "open_valve")  openValve(value);   // value = minutos
    else if (action == "close_valve") closeValve();
    else if (action == "alert_low_water") sendAlert();
  }
  http.end();
}
```

---

### Modo push — Mikhael empuja comandos vía MQTT

Cuando emitís un comando desde el browser (`⚡ Comandar`) o el CLI (`[c#]`), Mikhael
publica el resultado en el topic MQTT del dispositivo. El firmware lo recibe en tiempo real.

**Topic:** `mikhael/devices/<device_id>/command`

**Payload:**
```json
{ "action": "open_valve", "value": 30, "reason": "el usuario solicitó iniciar el riego" }
```

#### Setup del broker (Mosquitto)

```bash
# macOS
brew install mosquitto
brew services start mosquitto

# Linux
sudo apt install mosquitto mosquitto-clients
sudo systemctl start mosquitto
```

Agregá al `.env` de Mikhael:

```
MQTT_URL=mqtt://localhost:1883
```

Si `MQTT_URL` no está configurado, el modo push simplemente no envía nada — el modo
reactivo HTTP sigue funcionando igual.

#### Suscripción en ESP32 (Arduino + PubSubClient)

```cpp
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// Librería: PubSubClient by Nick O'Leary (instalar desde el Library Manager)

const char* MQTT_BROKER = "192.168.1.100";   // IP donde corre Mosquitto
const int   MQTT_PORT   = 1883;
const char* MQTT_TOPIC  = "mikhael/devices/riego_01/command";

WiFiClient   wifiClient;
PubSubClient mqtt(wifiClient);

void onCommand(char* topic, byte* payload, unsigned int length) {
  JsonDocument doc;
  deserializeJson(doc, payload, length);

  String action = doc["action"].as<String>();
  int    value  = doc["value"] | 0;
  bool   needs  = doc["requires_confirmation"] | false;

  if (needs) awaitUserConfirmation();

  if      (action == "open_valve")  openValve(value);
  else if (action == "close_valve") closeValve();
  else if (action == "alert_low_water") sendAlert();
}

void setup() {
  // ... WiFi connect ...
  mqtt.setServer(MQTT_BROKER, MQTT_PORT);
  mqtt.setCallback(onCommand);
}

void loop() {
  if (!mqtt.connected()) {
    mqtt.connect("esp32_riego");
    mqtt.subscribe(MQTT_TOPIC);
  }
  mqtt.loop();
  // ... leer sensores, lógica reactiva, etc. ...
}
```

#### Suscripción en MicroPython (ESP32)

```python
from umqtt.simple import MQTTClient
import ujson, time

BROKER    = "192.168.1.100"
DEVICE_ID = "riego_01"
TOPIC     = f"mikhael/devices/{DEVICE_ID}/command"

ACTIONS = {
    "open_valve":    lambda v: open_valve(v),
    "close_valve":   lambda _: close_valve(),
    "alert_low_water": lambda _: send_alert(),
}

def on_message(topic, payload):
    data   = ujson.loads(payload)
    action = data.get("action")
    value  = data.get("value")
    if action in ACTIONS:
        ACTIONS[action](value)

client = MQTTClient("esp32", BROKER)
client.set_callback(on_message)
client.connect()
client.subscribe(TOPIC)

while True:
    client.check_msg()   # non-blocking
    time.sleep_ms(100)
```

#### Emulador incluido — probar sin hardware

Mikhael incluye `bin/esp32_emulator` para verificar la integración completa sin un dispositivo
físico. Soporta ambos modos:

```bash
export DEVICE_TOKEN="tu_token_aqui"
export MQTT_URL=mqtt://localhost:1883

# Modo interactivo (te pregunta qué modo)
bin/esp32_emulator riego_01

# Solo modo reactivo (envía datos de sensor via HTTP)
bin/esp32_emulator riego_01 sensor

# Solo modo push (suscribe al topic MQTT y espera comandos)
bin/esp32_emulator riego_01 subscribe
```

**Ejemplo — modo push:**

```
ESP32 Emulator · device_id: riego_01
  MQTT: mqtt://localhost:1883  |  Mikhael: http://localhost:3000

╔══ MODO MQTT (push) ══════════════════════════╗
  Suscrito a: mikhael/devices/riego_01/command
  Esperando comandos desde Mikhael... (Ctrl+C para salir)

  ← Comando MQTT recibido [14:32:07]
  Comando recibido:
  action: open_valve
  value:  30
  reason: humedad crítica por debajo del umbral mínimo

  [GPIO] Válvula ABIERTA · 30 minutos
  ✓ Acción ejecutada.
```

Desde otro terminal (o el browser), comandás el dispositivo:

```bash
# Via CLI: [d] → [c1]
# Via browser: /devices → ⚡ Comandar
# Via curl:
curl -X POST http://localhost:3000/api/v1/devices/1/command \
  -H "Authorization: Basic $(echo -n 'mikhael:PASSWORD' | base64)" \
  -H "Content-Type: application/json" \
  -d '{"message": "La humedad está en 18%, iniciar riego"}'
```

---

## Uso 4 — Bot de Telegram

Mikhael puede correr como un bot de Telegram. Le hablás desde el celular y:

- Te dice qué dispositivos tenés
- Activa cualquiera de ellos (*"iniciá el riego"* → MQTT push al ESP32)
- Te avisa cuando un dispositivo ejecuta una acción importante

Lo bueno: **Mikhael nunca expone nada a internet**. Hace polling a Telegram cada 2 segundos
preguntando "¿hay mensajes para mí?". Tu Mikhael sigue corriendo solo en tu casa.

### Paso 1: Crear el bot en Telegram

1. Abrí Telegram y buscá `@BotFather` (es el bot oficial de Telegram para crear bots)
2. Mandale el comando `/newbot`
3. Te va a pedir un **nombre** para el bot (lo que vas a ver vos en el chat) — ej: `Mi Mikhael`
4. Te va a pedir un **username** que termine en `bot` — ej: `mi_mikhael_house_bot`
5. Te responde con un **token** así: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz_1234567890`

**Guardá ese token bien** — es la contraseña de tu bot.

### Paso 2: Obtener tu Chat ID

El Chat ID es un número que identifica tu conversación personal con el bot. Es necesario
para que Mikhael solo te responda a vos y no a cualquiera que descubra tu bot.

1. En Telegram, buscá tu bot por el username y mandale **cualquier mensaje** (un "hola" alcanza)
2. Abrí esta URL en el navegador (reemplazá `<TU_TOKEN>` por el que te dio BotFather):

   ```
   https://api.telegram.org/bot<TU_TOKEN>/getUpdates
   ```

3. Vas a ver algo así:

   ```json
   {
     "ok": true,
     "result": [{
       "message": {
         "chat": {
           "id": 987654321,         ← este es tu CHAT_ID
           "first_name": "Tu Nombre"
         },
         "text": "hola"
       }
     }]
   }
   ```

4. Copiá ese número que aparece en `"id"`.

> 💡 Si te aparece `result: []` (lista vacía), es porque todavía no le mandaste ningún
> mensaje al bot. Hacé el paso 1 (mandale "hola") y reintentá.

### Paso 3: Configurar Mikhael

Editá tu `.env` y agregá:

```env
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz_1234567890
TELEGRAM_CHAT_ID=987654321
ENABLE_TELEGRAM_POLLING=true
```

> 💡 `ENABLE_TELEGRAM_POLLING=true` es necesario en development. En producción Mikhael
> arranca el polling solo.

Reiniciá Mikhael (`Ctrl+C` y de nuevo `bin/dev`). Vas a ver en los logs:

```
Telegram polling iniciado.
```

### Paso 4: Probar

Abrí Telegram, andá a tu bot y mandale:

```
/start                     → Mikhael te saluda y te explica
/dispositivos              → Lista los devices que tenés cargados
/recordatorios             → Ver los próximos 10 recordatorios pendientes
/borrar_recordatorio <id>  → Cancela un recordatorio
/zona <nombre>             → Configura tu zona horaria (ej: /zona Buenos Aires)
/reset                     → Borra la conversación y empieza fresca

(o hablale natural)
"qué dispositivos tengo"
"iniciá el riego"
"abrí la cerradura"
"qué hora es"
"recordame en 2 horas revisar el riego"
"mañana a las 8 preguntale al ESP32 del riego cómo está"
"hola, cómo va?"
```

Mikhael conoce tus dispositivos, sabe sus acciones, y cuando le pedís ejecutar algo
**realmente lo ejecuta** — vía DispatchAction (interpreta) + MQTT (empuja al device).

### ¿Por qué solo a mi Chat ID?

El bot técnicamente es público en Telegram (cualquiera que sepa el username puede mandarle
mensajes). Pero Mikhael **solo procesa mensajes que vienen del Chat ID que vos configuraste**.
Cualquier otro mensaje se ignora.

Si querés que más gente pueda usar el bot (familia, etc.), hay que ampliar el código —
por ahora es single-user.

### Notificaciones automáticas

Cuando un microcontrolador llama a Mikhael (modo reactivo HTTP) y obtiene una acción,
Mikhael te manda un mensaje al Telegram avisándote:

```
📡 ESP32 Riego → open_valve
Valor: 30
humedad por debajo del umbral mínimo
```

Si el device reporta sin auth (modo reactivo) y la acción es de un device `high security`,
te llega con flag de confirmación física:

```
⚠️ ESP32 Cerradura → unlock
usuario autorizado en horario permitido
```

> 💡 **Nota:** cuando vos sos quien comanda desde Telegram (chat_id verificado), Mikhael
> NO pide confirmación física — vos sos la autorización. La confirmación física solo
> aparece cuando el ESP32 reporta por su cuenta (sensores, eventos), porque en ese caso
> el origen no es confiable. Ver sección [Seguridad](#seguridad) más abajo.

### Auto-reset cuando actualizás Mikhael

La conversación de Telegram se autorresea cuando cambia el system prompt (por un `git pull`
con cambios al bot, por ejemplo). No te tenés que acordar de mandar `/reset` después de
actualizar — Mikhael lo nota solo y arranca con la conversación fresca.

### Recordatorios programados

Mikhael entiende lenguaje natural para programar recordatorios y acciones diferidas:

```
"recordame en 5 minutos llamar al doctor"
"avisame en 2 horas revisar el riego"
"recordame mañana a las 8 sacar la basura"
"en 30 minutos preguntale al ESP32 del riego cómo está la humedad"
```

Dos tipos:

| `kind` | Qué hace |
|--------|----------|
| `notify` | Te manda un mensaje a Telegram con el texto del recordatorio |
| `query_device` | En ese momento llama al device (DispatchAction) y te manda el resultado a Telegram |

**Arquitectura:** los recordatorios son un *tool* del chat AI (`create_reminder`), igual
que `call_device`. Una sola llamada al modelo decide qué hacer. Si el AI no usa el tool
correctamente (alucina la fecha o se rinde y responde chat text), un fallback determinístico
extrae el "cuándo" y el "qué" del mensaje original del usuario y crea el recordatorio igual.

**Persistencia y ejecución:** los recordatorios viven en SQLite (tabla `reminders`) y se
ejecutan vía `ExecuteReminderJob` encolado en Solid Queue con `wait_until`. El job es
idempotente (no se ejecuta dos veces si `executed_at` ya está seteado) y tolerante a
dispositivos borrados.

**Defensa contra duplicados:** si el mismo pedido llega dos veces en < 30 segundos
(usuario impaciente, restart del server que reenvía updates viejos de Telegram, etc.),
solo se crea un Reminder. La segunda confirmación se omite en silencio.

**Gestión:**

```
/recordatorios              → próximos 10 pendientes
/borrar_recordatorio 3      → cancela el #3
```

### Zona horaria

Mikhael necesita saber tu zona para interpretar correctamente "mañana a las 8" y para
mostrar horas locales en las confirmaciones. Resolución en tres niveles (prioridad):

1. **Setting persistido en la app** — autodetectado por el browser la primera vez que
   abrís la web (Stimulus controller lee `Intl.DateTimeFormat().resolvedOptions().timeZone`
   y lo guarda vía `PATCH /timezone`). También se setea con el comando `/zona` desde Telegram.
2. **ENV `MIKHAEL_TZ`** — fallback para deployments sin browser (Telegram only / CLI only).
3. **UTC** — último recurso.

Desde Telegram:

```
/zona Buenos Aires           → setea zona con nombre amigable
/zona America/New_York       → o con nombre IANA completo
/zona                        → muestra la zona actual y de dónde viene
```

Si preguntás "qué hora es" y la zona no está configurada, Mikhael te responde la hora
en UTC con un hint sugiriendo el comando `/zona` para arreglarlo.

> 💡 **Nota técnica:** `Time.zone` en Rails es per-thread. El `TelegramPollJob` corre en
> un thread distinto al request del browser, así que Mikhael resuelve siempre vía
> `UserTimezone.current` (que lee del DB Setting) en vez de confiar en `Time.zone`.
> Funciona uniforme entre web, CLI y Telegram.

---

## Referencia de API

```
GET    /api/v1/models                              # lista modelos disponibles
GET    /api/v1/conversations                       # lista conversaciones
GET    /api/v1/conversations/:id                   # conversación + mensajes
POST   /api/v1/conversations                       # crear conversación
DELETE /api/v1/conversations/:id                   # eliminar
POST   /api/v1/conversations/:id/messages          # enviar mensaje al chat
GET    /api/v1/devices                             # lista dispositivos (sin token)
POST   /api/v1/devices                             # crear (devuelve token)
PATCH  /api/v1/devices/:id                         # actualizar
DELETE /api/v1/devices/:id                         # eliminar
POST   /api/v1/devices/:id/regenerate_token        # invalida el viejo, devuelve nuevo
POST   /api/v1/devices/:id/command                 # comando en lenguaje natural → acción + MQTT push
POST   /api/v1/action                              # endpoint para microdispositivos (auth por token)
PATCH  /timezone                                   # browser reporta su zona (Stimulus auto-detect)
```

Si `MIKHAEL_PASSWORD` está seteado, todas las rutas anteriores **excepto `/api/v1/action`**
exigen HTTP Basic Auth con usuario `mikhael` y la password configurada.

`/api/v1/devices/:id/command` recibe `{ "message": "texto libre" }` e interpreta el comando
usando el AI con el system prompt y las acciones configuradas del dispositivo. Si `MQTT_URL`
está activo, también publica el resultado al topic `mikhael/devices/<device_id>/command`.

### Rate Limits

Todos los endpoints tienen rate limiting nativo (Rails 8 `rate_limit` con `MemoryStore`).
Las respuestas 429 incluyen `Retry-After` (segundos) y body:

```json
{ "error": "rate_limit_exceeded", "retry_after": 30 }
```

| Endpoint | Límite | Por |
|----------|--------|-----|
| `POST /api/v1/action` | 60 req/min | Token de dispositivo |
| `POST /api/v1/conversations/:id/messages` | 30 req/min | IP |
| `POST /api/v1/conversations/:id/messages/stream` | 30 req/min | IP |
| `POST /api/v1/devices/:id/command` | 30 req/min | IP |
| Rutas web | 100 req/min | IP |
| Telegram polling | Sin límite | — (interno) |

Variables de entorno para ajustar los límites:

| Variable | Default | Aplica a |
|----------|---------|----------|
| `RATE_LIMIT_ACTION_PER_MIN` | `60` | `POST /api/v1/action` |
| `RATE_LIMIT_MESSAGES_PER_MIN` | `30` | Messages, stream, device command |
| `RATE_LIMIT_WEB_PER_MIN` | `100` | Rutas web |

---

## Seguridad

### Modelo de amenaza

Mikhael fue diseñado pensando en uso personal (1 usuario, localhost o LAN privada). Lo
que cubrimos por defecto:

- ✅ Tokens de dispositivo de **256 bits** (no bruteables)
- ✅ `force_ssl` activado en producción
- ✅ Tokens filtrados en logs (`filter_parameters` incluye `:token`)
- ✅ Tokens **solo se muestran al crear o regenerar** — no se exponen en listados
- ✅ Endpoint de action protegido por Bearer token con `secure_compare`
- ✅ Bot de Telegram **solo procesa mensajes del `TELEGRAM_CHAT_ID` configurado** — el resto se ignora
- ✅ **Rate limiting** nativo por endpoint con `Retry-After` — ver sección [Rate Limits](#rate-limits)
- ✅ Logs de rate limit incluyen solo los primeros 8 chars del identificador (nunca el token completo)
- ✅ Brakeman: 0 warnings en escaneo de seguridad

### Trusted sources — confirmación física inteligente

Cuando un device es `security_level: high` y vos lo comandás desde Telegram (chat_id
verificado) o desde la web autenticada, Mikhael **no pide confirmación física** — la
autenticación al borde (chat_id, basic auth) ya prueba que sos vos. Pedir además que
aprietes un botón físico es absurdo si querés abrir la puerta de tu casa estando en otro
lado.

Cuando el ESP32 le pregunta a Mikhael por su cuenta (modo reactivo, leyendo sensores), el
flag `requires_confirmation: true` SÍ se devuelve para devices high — porque el origen
no tiene autenticación humana. Le toca al firmware pedir confirmación física antes de
ejecutar.

| Origen | Trusted | requires_confirmation en high-sec |
|---|---|---|
| Telegram (chat_id linkeado a un User) | ✅ | No |
| Web (sesión iniciada) | ✅ | No |
| CLI con `Authorization: Bearer <user_api_token>` | ✅ | No |
| ESP32 reportando sensores | ⚠️ | Sí |

### Autenticación multi-user

Mikhael tiene autenticación real con users (email + password). Las cuentas las crea el
admin **vía consola** — no hay signup público porque es un asistente personal/familiar,
no SaaS:

```bash
bin/rails users:create EMAIL=tu@email.com PASSWORD=algo_de_12_chars_minimo
# Opcional: TELEGRAM_CHAT_ID=12345  (para que ese user reciba mensajes del bot)
```

El comando imprime el `api_token` del user — guardalo, lo necesita el CLI para autenticar
contra `/api/v1/*`. Si lo perdés:

```bash
bin/rails users:regenerate_token EMAIL=tu@email.com
```

**Modelo de scoping:**
- Per-user: conversaciones, recordatorios, zona horaria, api_token, telegram_chat_id
- Compartidos (hogar): dispositivos IoT, ModelConfig

**Hardening:**
- `has_secure_password` (bcrypt). Mínimo 12 caracteres.
- Brute-force protection en login: 5 intentos por minuto por IP (configurable
  con `RATE_LIMIT_LOGIN_PER_MIN`). Después, 429.
- Mensaje genérico ("Email o contraseña incorrectos") para no revelar si el email existe.
- `reset_session` en cada login para prevenir session fixation.
- Cookie de sesión: `httponly`, `secure` en producción, `same_site: :lax`.
- Rate limiting por user_id cuando hay sesión (y por IP cuando no).

### Buenas prácticas recomendadas

- Para acceso remoto, **usá Tailscale o WireGuard** en vez de port-forwarding directo
- Si exponés via Cloudflare Tunnel, activá **Cloudflare Access** además del password
- **Regenerá tokens** de devices periódicamente (`POST /api/v1/devices/:id/regenerate_token`)
- **No commitees `.env`** — ya está en `.gitignore`

---

## Arquitectura

```
app/
├── controllers/
│   ├── concerns/
│   │   └── app_authentication.rb       # HTTP Basic Auth opcional (MIKHAEL_PASSWORD)
│   ├── conversations_controller.rb     # Web (Turbo)
│   ├── messages_controller.rb          # Web (Turbo Stream)
│   ├── devices_controller.rb           # Web (gestión de microdispositivos)
│   ├── model_configs_controller.rb     # Web (system prompts por modelo)
│   ├── timezone_controller.rb          # Recibe TZ autodetectada del browser (Stimulus)
│   └── api/v1/
│       ├── conversations_controller.rb
│       ├── messages_controller.rb
│       ├── message_streams_controller.rb  # SSE para streaming al CLI
│       ├── models_controller.rb        # GET — lista de modelos disponibles
│       ├── devices_controller.rb       # CRUD + regenerate_token
│       └── actions_controller.rb       # POST — endpoint para microdispositivos
├── jobs/
│   ├── telegram_poll_job.rb            # Long-polling de Telegram (offset persistido en Setting)
│   └── execute_reminder_job.rb         # Dispara recordatorios, idempotente, encolado con wait_until
├── operations/
│   ├── create_message.rb               # Pipeline: validar → guardar user → AI → guardar assistant
│   └── dispatch_action.rb              # AI con retry y output JSON estructurado
├── services/
│   ├── model_selector.rb               # Tiers, fallback chain, cooldown por rate limit
│   ├── ollama_models.rb                # Cache 60s de /api/tags
│   │
│   │ ─── Capa unificada "AI sugiere, Rails ejecuta" (web + Telegram) ───
│   ├── assistant_context.rb            # System prompt + primer + hora actual. Surface-aware (:web/:telegram)
│   ├── command_router.rb               # Slash commands (/zona, /dispositivos, /recordatorios, /borrar_recordatorio)
│   ├── message_intent_router.rb        # Interceptor determinístico: hora, lista de devices
│   ├── tool_call_executor.rb           # Parsea respuesta AI → ejecuta call_device / create_reminder en Rails
│   │
│   ├── telegram_message_handler.rb     # Shim delgado para Telegram (delega a los services compartidos)
│   ├── user_timezone.rb                # Resolución TZ: Setting > ENV > UTC
│   └── ai/
│       ├── dispatcher.rb               # Resuelve provider → client
│       ├── base_client.rb
│       ├── ruby_llm_client.rb          # Ollama + Groq (via RubyLLM)
│       ├── openai_compatible_client.rb # Base para providers OpenAI-compatible
│       ├── cerebras_client.rb
│       └── sambanova_client.rb
├── models/
│   ├── conversation.rb                 # provider derivado de model_id
│   ├── message.rb
│   ├── model_config.rb                 # system prompt por modelo, auto-crea defaults
│   ├── device.rb                       # token 256-bit, security_level
│   ├── reminder.rb                     # scheduled_for, message, kind (notify|query_device)
│   └── setting.rb                      # key/value persistente (TZ del user, offset de Telegram, etc)
└── values/
    └── ai_response.rb                  # Data.define(:content, :model, :provider)
```

### Decisiones de diseño

- **AI sugiere, Rails ejecuta**: el principio rector. Toda la "potencia" del asistente
  (ejecutar dispositivos, programar recordatorios, decir la hora, listar devices) está
  implementada en Ruby/Rails. El AI es un parser de lenguaje natural que sugiere qué
  acción tomar (vía tools) o qué información buscar. Si el AI alucina, Rails tiene la
  última palabra y desestima la fabricación.
- **Una sola capa lógica para web y Telegram**: `AssistantContext`, `CommandRouter`,
  `MessageIntentRouter` y `ToolCallExecutor` se comparten. `MessagesController` (web) y
  `TelegramMessageHandler` son shims delgados que solo manejan I/O (cable broadcast vs
  HTTP a Telegram). Agregar una nueva superficie (Discord, WhatsApp...) es escribir un
  shim, no reimplementar lógica.
- **Provider derivado, no input**: `Conversation#provider` se computa siempre desde
  `model_id`. Evita estados inconsistentes (`provider=ollama` con `model_id` de Groq).
- **Ollama dinámico**: la lista de modelos locales se consulta con `/api/tags` en runtime
  (cacheado 60s) en vez de hardcodearla.
- **ModelConfig auto-crea defaults**: la primera vez que se pide el prompt de un modelo,
  se persiste el default. No hace falta correr `db:seed` cada vez que se agrega un modelo.
- **Output JSON robusto para devices**: `DispatchAction` reintenta hasta 6 veces con
  modelos distintos si el LLM devuelve JSON malformado o no respeta el esquema.
- **Recordatorios como tool, no como detector aparte**: `create_reminder` vive en el
  mismo system prompt que `call_device`. Una llamada AI por mensaje. Los LLMs son
  confiables eligiendo entre tools (para lo que están entrenados) y malos haciendo
  meta-clasificación de intent.
- **Fallback determinístico cuando el AI falla**: si el modelo no usa el tool, o devuelve
  una fecha alucinada en el pasado, o se rinde y responde chat text, una regex sobre el
  mensaje original del usuario rescata la intención. No dependemos de que el AI haga lo
  correcto.
- **Hora actual en cada turno via XML tags**: el `dynamic_prompt` inyecta hora UTC + local
  cada request. Estructurado con tags `<hechos_del_turno_actual>` que los LLMs respetan
  mejor que prosa libre.
- **TZ persistida en DB, no en `Time.zone`**: `Time.zone` es per-thread y se pierde entre
  el request del browser y el TelegramPollJob. `UserTimezone` lee siempre del DB
  (`Setting` > ENV > UTC) así funciona uniforme entre superficies.
- **Offset del polling persistente**: el `TelegramPollJob` guarda el offset en `Setting`
  (DB) en vez de `Rails.cache` (memoria volátil en dev). Reinicios del server ya no
  re-procesan mensajes viejos.
- **Multi-user con signup cerrado**: el admin crea cuentas vía CLI. Sin signup público
  porque Mikhael no es SaaS. Sessions con `httponly` + `secure` cookies, brute-force
  protection en login (rate_limit por IP), per-user rate limiting cuando hay user
  identificable. Devices son shared (hogar); conversaciones, recordatorios y zona horaria
  son per-user.
- **Conversación de Telegram identificada por user+title, no por cache**: antes la
  conversación se identificaba por una key en Rails.cache (que se borra en restart).
  Ahora es `user.conversations.where(title: "Telegram").first` — determinístico, sin
  dependencia de cache, multi-user-safe.

---

## Tests

```bash
bundle exec rspec
```

**240 ejemplos** cubriendo:

- **Unit specs** (services, models, jobs): `AssistantContext`, `CommandRouter`,
  `MessageIntentRouter`, `ToolCallExecutor`, `UserTimezone`, `Setting`, `Reminder`,
  `User` (auth, scoping, api_token), `ExecuteReminderJob`, dispatcher AI, OllamaModels,
  ModelSelector.
- **Request specs**: Sessions (login/logout/CSRF/return_to/fixation), API JSON con Bearer
  token (actions, conversations, messages, devices, heartbeat, models — incluyendo
  scoping cross-user de 404), rate limiting per-user, web `MessagesController` (commands +
  intents + tool execution), endpoint `PATCH /timezone`.
- **System specs** (Capybara + Cuprite, Chrome headless): flujos reales en browser —
  login + logout, slash commands, intent router, ejecución de tool calls del AI, fallback
  de recordatorios, scoping cross-user (Alice no ve datos de Bob). No mockean al user —
  tipean en el form y verifican que la DB cambió.

```bash
bundle exec rspec spec/system  # solo browser tests
```

```bash
bundle exec brakeman    # análisis estático de seguridad — debería pasar con 0 warnings
```

---

## Roadmap post-v1

| Idea | Notas |
|------|-------|
| Multi-usuario | Modelo `User`, sesiones, particionar todo por usuario |
| Bridge BLE | Daemon Python que traduce GATT ↔ HTTP local |
| Memoria entre conversaciones | Embeddings + recuperación contextual |
| Whisper local | Entrada por voz desde el CLI o devices |
| Bot Telegram multi-usuario | Cada `chat_id` con su propia conversación |

---

## Licencia

Licensed under **AGPL-3.0**. Ver [LICENSE](LICENSE).

Copyright (C) 2026 Nicolás S. Navarro

La AGPL es copyleft: si modificás Mikhael y lo ofrecés como servicio en red, tenés que
publicar tu código modificado. Si solo lo usás vos para vos, hacé lo que quieras.

---

<div align="center">

Construido con ☕ por alguien que claramente tiene **muy** pocas horas libres.

</div>
