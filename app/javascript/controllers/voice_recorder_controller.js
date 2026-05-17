import { Controller } from "@hotwired/stimulus"

// Graba audio del micrófono y lo transcribe via Groq Whisper.
// Al terminar, inyecta el texto en el textarea del form y lo envía.
//
// Uso en el HTML:
//   data-controller="voice-recorder"
//   data-voice-recorder-url-value="..."        (endpoint POST /transcribe)
//   data-voice-recorder-form-selector-value="..." (selector del form a enviar)
export default class extends Controller {
  static values = {
    url:          String,
    formSelector: String,
  }

  static targets = ["button", "icon", "status"]

  // Estados: idle | recording | uploading
  #state      = "idle"
  #recorder   = null
  #chunks     = []
  #stream     = null

  disconnect() {
    this.#stopStream()
  }

  async toggle() {
    if (this.#state === "idle")      await this.#startRecording()
    else if (this.#state === "recording") this.#stopRecording()
  }

  // ─── Grabación ────────────────────────────────────────────────────────────

  async #startRecording() {
    try {
      this.#stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch {
      this.#showError("Permiso de micrófono denegado.")
      return
    }

    this.#chunks  = []
    this.#recorder = new MediaRecorder(this.#stream)

    this.#recorder.ondataavailable = (e) => {
      if (e.data.size > 0) this.#chunks.push(e.data)
    }

    this.#recorder.onstop = () => this.#upload()

    this.#recorder.start()
    this.#setState("recording")
  }

  #stopRecording() {
    this.#recorder?.stop()
    this.#stopStream()
    this.#setState("uploading")
  }

  #stopStream() {
    this.#stream?.getTracks().forEach(t => t.stop())
    this.#stream = null
  }

  // ─── Upload y transcripción ───────────────────────────────────────────────

  async #upload() {
    const mimeType = this.#recorder?.mimeType || "audio/webm"
    const ext      = mimeType.includes("ogg") ? "ogg" : "webm"
    const blob     = new Blob(this.#chunks, { type: mimeType })

    const form = new FormData()
    form.append("audio", blob, `voice.${ext}`)

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    let response
    try {
      response = await fetch(this.urlValue, {
        method:  "POST",
        headers: { "X-CSRF-Token": csrfToken },
        body:    form,
      })
    } catch {
      this.#showError("Error de red al subir el audio.")
      return
    }

    const data = await response.json().catch(() => ({}))

    if (!response.ok) {
      const messages = {
        rate_limited: "Whisper alcanzó el límite diario. Intentá mañana o escribilo.",
        unavailable:  "Whisper no está disponible (falta GROQ_API_KEY).",
        no_audio:     "No se recibió audio.",
      }
      this.#showError(messages[data.error] || "No pude transcribir el audio.")
      return
    }

    this.#injectAndSubmit(data.text)
  }

  // ─── Inyección en el form ─────────────────────────────────────────────────

  #injectAndSubmit(text) {
    const form = document.querySelector(this.formSelectorValue)
    if (!form) { this.#setState("idle"); return }

    const textarea = form.querySelector("textarea")
    if (!textarea) { this.#setState("idle"); return }

    textarea.value = text
    this.#setState("idle")
    form.requestSubmit()
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  #setState(state) {
    this.#state = state

    const icons    = { idle: "🎙", recording: "⏹", uploading: "⏳" }
    const titles   = { idle: "Grabar mensaje de voz", recording: "Detener grabación", uploading: "Transcribiendo..." }
    const disabled = state === "uploading"

    if (this.hasIconTarget)   this.iconTarget.textContent   = icons[state]   ?? "🎙"
    if (this.hasButtonTarget) {
      this.buttonTarget.title    = titles[state] ?? ""
      this.buttonTarget.disabled = disabled
      this.buttonTarget.classList.toggle("animate-pulse", state === "recording")
      this.buttonTarget.classList.toggle("text-red-400",  state === "recording")
      this.buttonTarget.classList.toggle("text-zinc-400", state !== "recording")
    }
    if (this.hasStatusTarget) this.statusTarget.textContent = state === "uploading" ? "Transcribiendo..." : ""
  }

  #showError(msg) {
    this.#setState("idle")
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = msg
      setTimeout(() => { this.statusTarget.textContent = "" }, 4000)
    }
  }
}
