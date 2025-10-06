import { Controller } from 'stimulus';

export default class SearchController extends Controller {
  static get targets() {
    return [
      'address',
      'lat',
      'lng',
    ];
  }

  connect() {
    // Check if Google Maps is already loaded
    if (window.google && window.google.maps && window.google.maps.places) {
      this.initializeAutocomplete();
    } else {
      // Wait for Google Maps to load asynchronously
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
