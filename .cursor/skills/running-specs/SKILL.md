---
name: running-specs
description: >-
  Run RSpec tests in the sweeparoundus Docker environment. Use when running
  specs, tests, rspec, or any test suite commands in this project.
---

# Running Specs

## Docker Environment

This project runs in Docker via `docker compose`. The `.env` file sets
`RAILS_ENV=development`, which overrides the `ENV['RAILS_ENV'] ||= 'test'`
in `rails_helper.rb`. You **must** pass `-e RAILS_ENV=test` to avoid running
specs against the development database.

## Command

```bash
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec <spec files/dirs>
```

## Examples

Run a single spec file:

```bash
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec spec/models/area_spec.rb
```

Run all specs:

```bash
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec
```

## Resetting the Test Database

If you hit stale-data or schema errors, reset the test DB first:

```bash
docker compose run --rm app bash -c 'RAILS_ENV=test bundle exec rails db:drop db:create db:schema:load'
```

## Common Pitfall

**Never** omit `-e RAILS_ENV=test`. Without it, specs silently connect to the
development database, causing factory uniqueness violations from seeded data.
