import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return [
      'address',
      'lat',
      'lng',
    ];
  }

  connect() {
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

  placeChanged() {
    const place = this.autocomplete.getPlace();
    const { lat, lng } = place.geometry.location;

    this.latTarget.value = lat();
    this.lngTarget.value = lng();
    this.element.submit();
  }
}
