import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ['panel', 'button'];
  }

  toggle() {
    const isOpen = this.panelTarget.classList.toggle('hidden') === false;

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute('aria-expanded', String(isOpen));
    }

    if (isOpen) {
      const input = this.panelTarget.querySelector('input[name="address"]');
      if (input) input.focus();
    }
  }
}
