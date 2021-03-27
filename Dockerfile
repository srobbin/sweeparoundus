# Base image
FROM ruby:2.7.3-slim

# Environment variables
ENV PATH "$PATH:/usr/local/go/bin:/root/go/bin"

# Install dependencies
RUN apt-get update -qq \
  && apt-get install -y build-essential libpq-dev postgresql-client libgeos-dev vim
RUN gem install bundler -v 2.2.15

# Set the working directory
WORKDIR /app

# Copy the Gemfile and cached gems
COPY Gemfile Gemfile.lock ./

# Run bundle install to install gems inside the gemfile
RUN bundle install

# Copy files
COPY . .
