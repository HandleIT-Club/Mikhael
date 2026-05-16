import { Controller } from "@hotwired/stimulus"

// Detecta la zona horaria del browser y la reporta al server una vez por
// sesión. Cacheado en sessionStorage para no spamear el endpoint.
//
// Uso: <body data-controller="timezone">  (en el layout principal)
export default class extends Controller {
  connect() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!tz) return

    const cached = sessionStorage.getItem("mikhael_tz_reported")
    if (cached === tz) return

    // CSRF: Rails exige X-CSRF-Token para POST/PATCH/PUT/DELETE no-GET. El
    // meta tag lo emite csrf_meta_tags en el layout. Sin esto el server
    // pierde la sesión y no podemos persistir.
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content

    fetch("/timezone", {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept":       "application/json",
        "X-CSRF-Token": csrf
      },
      body: JSON.stringify({ timezone: tz })
    }).then(res => {
      if (res.ok) sessionStorage.setItem("mikhael_tz_reported", tz)
    }).catch(() => { /* falló — el server caerá a ENV/UTC; reintenta la próxima carga */ })
  }
}
