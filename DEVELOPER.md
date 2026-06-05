# Developer Guide

Developer setup, workflows, and operational runbooks for [We The Sweeple](http://wethesweeple.com). For the project overview and public API, see the [README](README.md).

## Development

### Initial setup

If this is your first time running the application, you'll need to make sure you have [Docker](https://docs.docker.com/get-docker/) installed. Assuming you do, issue these commands from the terminal:

```sh
# Make a copy of the environment variables file
# NOTE: You'll need a Google API key for maps/address autocomplete,
# and a SendGrid API key for sending transactional emails
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

*Note: you may be required to migrate the database, but you should be able to do this from the website prompt.*

### Gems and console

From time to time, you'll need to install new gems and access the console. In order to do so, use the `docker compose run app` command. For example:

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

### Linting

This project uses [RuboCop](https://rubocop.org/) with the [rails-omakase](https://github.com/rails/rubocop-rails-omakase) style guide. A pre-commit hook runs RuboCop automatically on staged `.rb` files.

```sh
# Check all files
docker compose run --rm --no-deps app bundle exec rubocop

# Auto-fix correctable offenses
docker compose run --rm --no-deps app bundle exec rubocop -a

# Check specific files
docker compose run --rm --no-deps app bundle exec rubocop app/models/area.rb
```

### Emails

In development, emails are captured and viewable at [http://localhost:3000/letter_opener](http://localhost:3000/letter_opener).

## Annual maintenance

- In late March, export the following files from the [Chicago Data Portal](data.cityofchicago.org):
  - "Street Sweeping Zones - 202X" => `Street Sweeping Zones - 202X.geojson`
  - "Street Sweeping Schedule - 202X" => `Street_Sweeping_Schedule_-_202X.csv`
  - "Ward Offices" => `Ward_Offices_202X.csv`
- Add files to the `db/data` directory.
- Run rspec test suite.
- Merge into main and deploy.
- Temporarily enable 'Maintenance Mode' on Heroku.
- Seed db with new zone and schedule data (note that this will nullify `area_id` in existing alerts):
  - TEST: `SeedYearlyData.new(write: false, year: Time.current.year.to_s).call`
  - `SeedYearlyData.new(write: true, year: Time.current.year.to_s).call`
- Disable 'Maintenance Mode' on Heroku.
- Set `NEW_SCHEDULES_LIVE = true` in `app/controllers/home_controller.rb` (controls the home page banner until schedules go live).
- Destroy alerts that are unconfirmed or don't have an associated street address:
  - TEST: `DestroyIneligibleAlerts.new(write: false).call`
  - `DestroyIneligibleAlerts.new(write: true).call`
- Carry over existing alerts:
  - TEST: `CarryOverExistingAlerts.new(write: false).call`
  - `CarryOverExistingAlerts.new(write: true).call`
- Notify ward offices that new schedules are live:
  - TEST: `NotifyWardOffices.new(write: false, year: Time.current.year.to_s).call`
  - `NotifyWardOffices.new(write: true, year: Time.current.year.to_s).call`

## Mid-season schedule corrections

If the City publishes a corrected `Street_Sweeping_Schedule_-_202X.csv` mid-season (the GeoJSON zones have not changed and alerts have already received their `annual_schedule_live` welcome email), refresh just the sweep data without touching `Area` records:

- Replace `db/data/Street_Sweeping_Schedule_-_202X.csv` with the corrected file.
- Run rspec test suite.
- Merge into main and deploy.
- Temporarily enable 'Maintenance Mode' on Heroku.
- Re-seed the schedule only; `Area` records are left intact, so existing `alert.area_id` values remain valid and no follow-up `CarryOverExistingAlerts` run is needed:
  - TEST: `SeedYearlyData.new(write: false, year: Time.current.year.to_s, skip_geojson: true).call`
  - `SeedYearlyData.new(write: true, year: Time.current.year.to_s, skip_geojson: true).call`
- Disable 'Maintenance Mode' on Heroku.

