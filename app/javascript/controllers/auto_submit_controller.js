import { Controller } from "@hotwired/stimulus"

// Submits the form when an input fires the configured action (e.g. change).
// Connect with `data-controller="auto-submit"` on the form and
// `data-action="change->auto-submit#submit"` on the input.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
