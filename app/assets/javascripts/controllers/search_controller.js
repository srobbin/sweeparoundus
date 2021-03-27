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
    google.maps.event.removeListener(this.autocomplete, 'place_changed', this.boundPlaceChanged);
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
