# SweepAround.Us

A Chicago street sweeping alert system and searchable calendar.

## Development

### Initial setup

If this is your first time running the application, you'll need to make sure you have
[Docker](https://docs.docker.com/get-docker/) installed. Assuming you do, issue these commands
from the terminal:

```sh
# Make a copy of the environment variables file
# NOTE: You'll need a Google API key for maps/address autocomplete,
# and a Mailgun API key for sending transactional emails
cp .env.example .env

# Build the Docker image
docker compose build --no-cache

# Run the setup script
docker compose run app bin/setup

# After the setup is completed, run the app
docker compose up
```

### Running the app

From a terminal session:

```sh
# Update to make sure your database and dependencies are in sync
docker compose run app bin/update

# Launch the stack
docker compose up
```

Once the stack is running, visit: [http://localhost:3000](http://localhost:3000)

_Note: you may be required to migrate the database, but you should be able to do this from
the website prompt._

### Gems and console

From time to time, you'll need to install new gems and access the console. In order to do so,
please use the `docker compose run app` command. For example:

```sh
# Installing gems
docker compose run app bundle add foo

# Accessing the console
docker compose run app bin/rails console

# Start a bash shell
docker compose run app /bin/bash

# Run rspec tests
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec
```

### Emails

In development, emails are captured and stored in `/tmp/letter_opener`.

## API

### `GET /api/v1/sweeps`

Returns the sweep area and next scheduled sweep dates for a given location.

**Parameters**

| Name  | Type  | Required | Description       |
|-------|-------|----------|-------------------|
| `lat` | float | yes      | Latitude (−90–90) |
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

| Status | Condition                      | Body |
|--------|--------------------------------|------|
| 422    | Missing `lat` or `lng`         | `{"error": "Missing required parameter: lat"}` |
| 422    | Non-numeric or out-of-range    | `{"error": "Invalid coordinates."}` |
| 404    | No sweep area at coordinates   | `{"error": "No sweep area found for the given coordinates."}` |
| 429    | Rate limit exceeded            | `{"error": "Rate limit exceeded. Try again later."}` |

**Rate limiting** — API requests are throttled to 60 per hour per IP. Throttled responses include a `Retry-After` header.

### Annual maintenance

- In late March, export the following files from the [Chicago Data Portal](data.cityofchicago.org):
  - "Street Sweeping Zones - 202X" => `Street Sweeping Zones - 202X.geojson`
  - "Street Sweeping Schedule - 202X" => `Street_Sweeping_Schedule_-_202X.csv`
- Add files to the `db/data` directory.
- Run rspec test suite.
- Merge into main and deploy.
- Temporarily enable 'Maintenance Mode' on Heroku prior to running non-TEST `SeedYearlyData` service.
- Seed db with new zone and schedule data (note that this will nullify `area_id` in existing alerts):
  - TEST: `SeedYearlyData.new(write: false, year: Time.current.year.to_s).call`
  - `SeedYearlyData.new(write: true, year: Time.current.year.to_s).call`
- Disable 'Maintenance Mode' on Heroku prior to running non-TEST `SeedYearlyData` service.
- Flip `NEW_SCHEDULES_LIVE` boolean value.
- Destroy alerts that are unconfirmed or don't have an associated street address:
  - TEST: `DestroyIneligibleAlerts.new(write: false).call`
  - `DestroyIneligibleAlerts.new(write: true).call`
- Carry over existing alerts:
  - TEST: `CarryOverExistingAlerts.new(write: false).call`
  - `CarryOverExistingAlerts.new(write: true).call`