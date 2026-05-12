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
    this.updateSubmitState();
    if (window.google && window.google.maps && window.google.maps.places) {
      this.initializeAutocomplete();
    } else {
      document.addEventListener('google-maps-loaded', () => {
        this.initializeAutocomplete();
      });
    }
  }

  initializeAutocomplete() {
    this.autocomplete = new google.maps.places.Autocomplete(this.addressTarget, {
      // Only show street addresses. Without this, Places returns businesses,
      // POIs, etc. whose coords can be far from their formatted address,
      // causing alerts to store mismatched address/coordinate pairs.
      types: ['address'],
      bounds: new google.maps.LatLngBounds(
        new google.maps.LatLng( 41.6446, -87.9395 ),
        new google.maps.LatLng( 42.0229, -87.5245 )
      )
    });

    this.boundPlaceChanged = this.placeChanged.bind(this);
    google.maps.event.addListener(this.autocomplete, 'place_changed', this.boundPlaceChanged);
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.boundSubmitEnd);
    if (this.autocomplete && google.maps && google.maps.event) {
      google.maps.event.removeListener(this.autocomplete, 'place_changed', this.boundPlaceChanged);
    }
  }

  resetAfterSubmit() {
    this.submitting = false;
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.add('hidden');
    if (this.hasLabelTarget) this.labelTarget.classList.remove('hidden');
    this.updateSubmitState();
  }

  submit(event) {
    event.preventDefault();
  }

  updateSubmitState() {
    if (!this.hasSubmitTarget) return;
    // Don't clobber a submit-in-flight: Places sometimes fires synthetic
    // input events after `place_changed`, and the user can also tap the
    // field after picking. Either would wipe the lat/lng we just filled
    // and abort the submission mid-flight.
    if (this.submitting) return;

    if (this.hasLatTarget) {
      this.latTarget.value = '';
    }
    if (this.hasLngTarget) {
      this.lngTarget.value = '';
    }
    this.submitTarget.disabled = true;
  }

  showLoading() {
    if (!this.hasSubmitTarget) return;

    this.submitTarget.disabled = true;
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.remove('hidden');
    if (this.hasLabelTarget) this.labelTarget.classList.add('hidden');
  }

  placeChanged() {
    // Guard against double-submit: if the user picks a place, then quickly
    // picks another before the in-flight POST returns, `place_changed`
    // would fire again and the server could persist two alerts (each with
    // a different geocoded address).
    if (this.submitting) return;

    const place = this.autocomplete.getPlace();
    if (!place || !place.geometry || !place.geometry.location) {
      return;
    }
    const { lat, lng } = place.geometry.location;

    this.latTarget.value = lat();
    this.lngTarget.value = lng();

    this.submitting = true;
    this.showLoading();
    this.element.submit();
  }
}
