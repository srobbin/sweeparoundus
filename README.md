# [We The Sweeple](http://wethesweeple.com)

A searchable Chicago street sweeping calendar and alert system.

> **Developers:** setup instructions, local workflows, and maintenance runbooks live in [DEVELOPER.md](DEVELOPER.md).

## API

### `GET /api/v1/sweeps`

Returns the sweep area and next scheduled sweep dates for a given location.

**Parameters**


| Name  | Type  | Required | Description          |
| ----- | ----- | -------- | -------------------- |
| `lat` | float | yes      | Latitude (−90–90)    |
| `lng` | float | yes      | Longitude (−180–180) |


**Example request**

```
GET /api/v1/sweeps?lat=41.885&lng=-87.712
```

**Success response** `200 OK`

```json
{
  "area": {
    "name": "Ward 28, Sweep Area 7",
    "shortcode": "W28A7",
    "url": "https://sweeparound.us/areas/ward-28-sweep-area-7",
    "next_sweep": {
      "dates": ["2026-04-15", "2026-04-16"],
      "formatted": "April 15 / April 16"
    }
  }
}
```

`next_sweep` is `null` when no upcoming sweep is scheduled.

**Error responses**


| Status | Condition                    | Body                                                          |
| ------ | ---------------------------- | ------------------------------------------------------------- |
| 422    | Missing `lat` or `lng`       | `{"error": "Missing required parameter: lat"}`                |
| 422    | Non-numeric or out-of-range  | `{"error": "Invalid coordinates."}`                           |
| 404    | No sweep area at coordinates | `{"error": "No sweep area found for the given coordinates."}` |
| 429    | Rate limit exceeded          | `{"error": "Rate limit exceeded. Try again later."}`          |


**Rate limiting**: API requests are throttled to 60 per hour per IP. Throttled responses include a `Retry-After` header.