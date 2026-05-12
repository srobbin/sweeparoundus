import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return [
      'address',
      'lat',
      'lng',
      'submit',
      'spinner',
      'label',
    ];
  }

  connect() {
    this.submitting = false;
    this.boundSubmitEnd = this.resetAfterSubmit.bind(this);
    this.element.addEventListener("turbo:submit-end", this.boundSubmitEnd);
    if (this.hasSubmitTarget) this.submitTarget.disabled = true;

    if (window.google && window.google.maps && window.google.maps.places) {
      this.configureAutocomplete();
    } else {
      document.addEventListener('google-maps-loaded', () => {
        this.configureAutocomplete();
      }, { once: true });
    }
  }

  configureAutocomplete() {
    this.addressTarget.locationBias = {
      west: -87.9395,
      south: 41.6446,
      east: -87.5245,
      north: 42.0229,
    };
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.boundSubmitEnd);
  }

  resetAfterSubmit() {
    this.submitting = false;
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.add('hidden');
    if (this.hasLabelTarget) this.labelTarget.classList.remove('hidden');
    if (this.hasSubmitTarget) this.submitTarget.disabled = true;
    if (this.hasLatTarget) this.latTarget.value = '';
    if (this.hasLngTarget) this.lngTarget.value = '';
    this.clearAutocompleteInput();
  }

  clearAutocompleteInput() {
    this.addressTarget.value = '';
    const input = this.addressTarget.shadowRoot?.querySelector('input');
    if (input) input.value = '';
  }

  submit(event) {
    event.preventDefault();
  }

  showLoading() {
    if (!this.hasSubmitTarget) return;

    this.submitTarget.disabled = true;
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.remove('hidden');
    if (this.hasLabelTarget) this.labelTarget.classList.add('hidden');
  }

  async placeChanged(event) {
    if (this.submitting) return;

    let place;
    try {
      place = event.placePrediction.toPlace();
      await place.fetchFields({ fields: ['location'] });
    } catch (e) {
      console.error('Places fetchFields failed:', e);
      return;
    }

    if (!place.location) return;

    this.latTarget.value = place.location.lat();
    this.lngTarget.value = place.location.lng();

    this.submitting = true;
    this.showLoading();
    this.element.submit();
  }
}
