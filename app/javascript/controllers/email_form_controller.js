import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ['input', 'submit'];
  }

  static values = {
    securityCheckRequired: Boolean
  }

  connect() {
    this.securityCheckPassed = !this.securityCheckRequiredValue
    this.toggle();
  }

  securityCheckSucceeded() {
    this.securityCheckPassed = true
    this.toggle()
  }

  securityCheckFailed() {
    this.securityCheckPassed = false
    this.toggle()
  }

  toggle() {
    const emailMissing = this.inputTarget.value.trim() === ''
    this.submitTarget.disabled = emailMissing || !this.securityCheckPassed
  }
}
