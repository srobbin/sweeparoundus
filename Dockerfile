# Base image
FROM ruby:2.7.5-slim

# Install dependencies
RUN apt-get update -qq \
  && apt-get install -y build-essential libpq-dev postgresql-client libgeos-dev vim

# Set the working directory
WORKDIR /app

# Install the gems
COPY Gemfile* .
ENV BUNDLE_PATH=/bundle \
    BUNDLE_BIN=/bundle/bin \
    GEM_HOME=/bundle
ENV PATH="${BUNDLE_BIN}:${PATH}"
RUN gem install bundler:2.3.9
RUN bundle install

# Copy files
COPY . .
