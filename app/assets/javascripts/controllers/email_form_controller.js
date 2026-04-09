import { Controller } from 'stimulus';

export default class EmailFormController extends Controller {
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
