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
    if (this.autocomplete && google.maps && google.maps.event) {
      google.maps.event.removeListener(this.autocomplete, 'place_changed', this.boundPlaceChanged);
    }
  }

  submit(event) {
    event.preventDefault();
  }

  updateSubmitState() {
    if (!this.hasSubmitTarget) return;

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
    const place = this.autocomplete.getPlace();
    if (!place || !place.geometry || !place.geometry.location) {
      return;
    }
    const { lat, lng } = place.geometry.location;

    this.latTarget.value = lat();
    this.lngTarget.value = lng();

    this.showLoading();
    this.element.submit();
  }
}
