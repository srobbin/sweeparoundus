import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { event: String, params: Object }

  track() {
    if (typeof gtag === "function") {
      gtag("event", this.eventValue, this.paramsValue)
    }
  }
}
