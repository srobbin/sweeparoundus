# SweepAround.Us

A Chicago street sweeping alert system and searchable calendar.

## Development

### Initial setup

If this is your first time running the application, you'll need to make sure you have
[Docker](https://docs.docker.com/get-docker/) installed. Assuming you do, issue these commands
from the terminal:

```sh
# Make a copy of the environment variables file
cp .env.example .env

# Install gems and initialize the database
docker-compose run web bundle install
docker-compose run web rails db:setup
```

### Running the app

From a terminal session:

```sh
# Launch the stack
docker-compose up
```

Once the stack is running, visit: [http://localhost:3000](http://localhost:3000)

_Note: you may be required to migrate the database, but you should be able to do this from
the website prompt._

### Gems and console

From time to time, you'll need to install new gems and access the console. In order to do so,
please use the `docker-compose run web` command. For example:

```sh
# Installing gems
docker-compose run web bundle install

# Accessing the console
docker-compose run web rails c
```

### Emails

In development, emails are captured and stored in `/tmp/letter_opener`.
