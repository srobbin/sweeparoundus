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
docker-compose build --no-cache

# Run the setup script
docker-compose run app bin/setup

# After the setup is completed, run the app
docker-compose up
```

### Running the app

From a terminal session:

```sh
# Update to make sure your database and dependencies are in sync
docker-compose run app bin/update

# Launch the stack
docker-compose up
```

Once the stack is running, visit: [http://localhost:3000](http://localhost:3000)

_Note: you may be required to migrate the database, but you should be able to do this from
the website prompt._

### Gems and console

From time to time, you'll need to install new gems and access the console. In order to do so,
please use the `docker-compose run app` command. For example:

```sh
# Installing gems
docker-compose run app bundle add foo

# Accessing the console
docker-compose run app bin/rails console

# Start a bash shell
docker-compose run app /bin/bash

# Run rspec tests
docker-compose run app rake spec
OR
docker-compose run app bundle exec rake spec
```

### Emails

In development, emails are captured and stored in `/tmp/letter_opener`.
