import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["map"]
  static values = {
    coordinates: Array,
    center: Array
  }

  connect() {
    this.neighborPolygons = new Map()

    if (typeof google !== "undefined" && typeof google.maps.Map === "function") {
      this.#initMap()
    } else {
      document.addEventListener("google-maps-loaded", () => this.#initMap(), { once: true })
    }
  }

  disconnect() {
    this.neighborPolygons.forEach((poly) => poly.setMap(null))
    this.neighborPolygons.clear()
    if (this.mainPolygon) this.mainPolygon.setMap(null)
    if (this.searchMarker) this.searchMarker.map = null
    this.map = null
  }

  toggle(event) {
    const checkbox = event.currentTarget
    const id = checkbox.dataset.neighborId
    const color = checkbox.dataset.color

    if (checkbox.checked) {
      this.#addNeighborPolygon(id, checkbox.dataset.coordinates, color)
      this.#addHiddenField(id)
    } else {
      this.#removeNeighborPolygon(id)
      this.#removeHiddenField(id)
    }

    if (this.map) this.#fitBounds()
  }

  lockNeighbors(event) {
    if (!event.detail.success) return

    this.element.querySelectorAll("input[data-neighbor-id]").forEach((checkbox) => {
      checkbox.disabled = true
      checkbox.classList.add("cursor-not-allowed", "opacity-50")
      checkbox.closest("[data-neighbor-card]").title =
        "To change your selections, subscribe again with the same email."
    })
  }

  #addNeighborPolygon(id, coordinatesJson, color) {
    if (!this.map) return

    const coords = JSON.parse(coordinatesJson)
    const paths = coords.map(([lat, lng]) => ({ lat, lng }))
    const polygon = new google.maps.Polygon({
      paths,
      strokeColor: color,
      strokeOpacity: 0.8,
      strokeWeight: 2,
      fillColor: color,
      fillOpacity: 0.2,
      map: this.map
    })
    this.neighborPolygons.set(id, polygon)
  }

  #removeNeighborPolygon(id) {
    const polygon = this.neighborPolygons.get(id)
    if (polygon) {
      polygon.setMap(null)
      this.neighborPolygons.delete(id)
    }
  }

  #addHiddenField(id) {
    const form = this.element.querySelector("#subscribe form")
    if (!form) return

    const input = document.createElement("input")
    input.type = "hidden"
    input.name = "neighbor_area_ids[]"
    input.value = id
    input.dataset.neighborHidden = id
    form.appendChild(input)
  }

  #removeHiddenField(id) {
    const field = this.element.querySelector(`input[data-neighbor-hidden="${id}"]`)
    if (field) field.remove()
  }

  #initMap() {
    const [lat, lng] = this.centerValue
    this.map = new google.maps.Map(this.mapTarget, {
      center: { lat, lng },
      zoom: 15,
      mapId: "area-map",
      mapTypeControl: false,
      streetViewControl: false
    })

    const paths = this.coordinatesValue.map(([lat, lng]) => ({ lat, lng }))
    this.mainPolygon = new google.maps.Polygon({
      paths,
      strokeColor: "#ff8c00",
      strokeOpacity: 0.8,
      strokeWeight: 2,
      fillColor: "#ff8c00",
      fillOpacity: 0.3,
      map: this.map
    })

    this.searchMarker = new google.maps.marker.AdvancedMarkerElement({
      position: { lat, lng },
      map: this.map,
      title: "Searched address"
    })

    this.#fitBounds()
  }

  #fitBounds() {
    const bounds = new google.maps.LatLngBounds()

    this.mainPolygon.getPath().forEach((point) => bounds.extend(point))
    this.neighborPolygons.forEach((poly) => {
      poly.getPath().forEach((point) => bounds.extend(point))
    })

    this.map.fitBounds(bounds)
  }
}
