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

### Testing

The full suite runs without touching the network and is safe for CI:

```sh
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec
```

#### FAQ external link liveness check

`spec/requests/faq_spec.rb` includes an opt-in check that actually fetches every external link on the FAQ page and confirms each one resolves. It hits the public internet, so it is **skipped by default** to keep the normal suite fast and deterministic (a third-party outage shouldn't fail an unrelated build). It follows redirects and retries timeouts/5xx/429 responses with a short backoff before failing.

Run it on demand by setting `CHECK_EXTERNAL_LINKS=1`:

```sh
docker compose run --rm -e RAILS_ENV=test -e CHECK_EXTERNAL_LINKS=1 app bundle exec rspec spec/requests/faq_spec.rb -e "external links resolve"
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

- Before the City publishes (late March), add the new year's dataset IDs to `SweepingDatasets::CONFIG` in [app/models/sweeping_datasets.rb](app/models/sweeping_datasets.rb). Without an entry for the current year, `CheckSweepingDataUpdatesJob` alerts (Sentry) and opens no PRs.
- In late March, export the following files from the [Chicago Data Portal](data.cityofchicago.org):
  - "Street Sweeping Zones - 202X" => `Street Sweeping Zones - 202X.geojson`
  - "Street Sweeping Schedule - 202X" => `Street_Sweeping_Schedule_-_202X.csv`
  - "Ward Offices" => `Ward_Offices_202X.csv`
- Add files to the `db/data` directory.
  - Note: Once the year's datasets are published and configured, `CheckSweepingDataUpdatesJob` will open the Schedule/Zones candidate PRs automatically (see "Automated in-season data updates" below), so the manual export of those two files is mainly for the initial pre-publish setup. `Ward_Offices_202X.csv` is **not** automated and is always exported/added by hand.
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

## Automated in-season data updates

A daily, in-season Sidekiq cron job (`CheckSweepingDataUpdatesJob`, `config/cron.yml`) watches the City's published Street Sweeping Schedule (CSV) and Zones (GeoJSON) datasets and opens a GitHub PR whenever they differ from the committed `db/data/` files. It does **not** validate in-process — the PR's CI run (the full RSpec suite, [.github/workflows/ci.yml](.github/workflows/ci.yml)) is the validation gate.

How it works:

- **Season + availability guards:** runs Mar 20–Nov 30 (America/Chicago). If there's no `SweepingDatasets` config for the year, the dataset 404s (not published yet), or the metadata is for the wrong year, it sends one `Sentry.capture_message` and opens no PR.
- **Change detection** is semantic (normalized CSV rows / parsed GeoJSON feature sets), so the City's export formatting (row order, quoting, key order) doesn't create false positives. The committed file *is* the baseline.
- **Idempotent PRs:** the branch name is a content hash, so the same data won't reopen daily. A closed-without-merge PR stays dismissed; delete its branch to force a re-open.
- **Sentry** is reserved for operational failures (network / GitHub API) via `retry_on` exhaustion, mirroring `SyncCdotPermitsJob`.

**Merging is not promotion.** A green CI check means the candidate is safe to merge, and merging + deploying lands the file in the slug — but the running database is unchanged until you run the seeding runbook above (full swap = Annual maintenance; CSV-only fix = Mid-season corrections). Treat a merged candidate PR as the trigger to run those steps.

### GitHub App ("We The Sweeple Data Bot")

The job authenticates as a GitHub App (App ID `4000424`, [public page](https://github.com/apps/we-the-sweeple-data-bot)) installed on `srobbin/sweeparoundus` with `contents: write` + `pull_requests: write`. It mints a short-lived installation token per run (no PAT, no annual expiry). Required env vars (Heroku config + local `.env`; placeholders in `.env.example`):

- `GITHUB_APP_ID` — `4000424` (not secret)
- `GITHUB_APP_INSTALLATION_ID` — `138932483` (not secret)
- `GITHUB_APP_PRIVATE_KEY` — the App's `.pem`, base64-encoded to a single line (`base64 -i key.pem | tr -d '\n'`); decoded at runtime. **Secret.**

To rotate the key: generate a new private key on the App's settings page, re-encode, and update the env var. To re-discover the installation ID after a reinstall: authenticate as the App and `GET /repos/srobbin/sweeparoundus/installation`.

### CI as a required check

[.github/workflows/ci.yml](.github/workflows/ci.yml) runs the full suite on every PR into `main` (Postgres/PostGIS + Redis service containers, `RAILS_ENV=test`). For the green/red check to actually gate merges, it must be configured as a **required status check** in `main`'s branch protection (repo Settings → Branches). This is a one-time repo-admin action.

