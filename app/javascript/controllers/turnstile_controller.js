import { Controller } from "@hotwired/stimulus"

const SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
let scriptPromise

function loadTurnstile() {
  if (window.turnstile) return Promise.resolve(window.turnstile)

  if (!scriptPromise) {
    scriptPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = SCRIPT_URL
      script.async = true
      script.defer = true
      script.addEventListener("load", () => resolve(window.turnstile), { once: true })
      script.addEventListener("error", reject, { once: true })
      document.head.appendChild(script)
    }).catch((error) => {
      scriptPromise = undefined
      throw error
    })
  }

  return scriptPromise
}

export default class extends Controller {
  static values = {
    siteKey: String,
    action: String
  }

  connect() {
    // Turbo snapshots clone the widget markup before Stimulus disconnects.
    // Remove any stale iframe/token before rendering a fresh, single-use token.
    this.element.replaceChildren()

    loadTurnstile()
      .then((turnstile) => {
        if (!this.element.isConnected || this.widgetId !== undefined) return

        this.widgetId = turnstile.render(this.element, {
          sitekey: this.siteKeyValue,
          action: this.actionValue,
          callback: () => this.dispatch("succeeded"),
          "expired-callback": () => this.dispatch("failed"),
          "error-callback": () => this.dispatch("failed")
        })
      })
      .catch(() => {
        this.element.textContent = "Verification is unavailable. Please reload and try again."
        this.dispatch("failed")
      })
  }

  disconnect() {
    if (this.widgetId !== undefined && window.turnstile) {
      window.turnstile.remove(this.widgetId)
      this.widgetId = undefined
    }
  }
}
