import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ['input', 'submit'];
  }

  connect() {
    this.toggle();
  }

  toggle() {
    this.submitTarget.disabled = this.inputTarget.value.trim() === '';
  }
}
