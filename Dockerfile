########
# BASE #
########

FROM ruby:3.4.3-slim as base

# Install dependencies
RUN apt-get update -qq \
  && apt-get install -y build-essential libpq-dev postgresql-client libgeos-dev vim

# Set the working directory and copy files
WORKDIR /app
COPY . ./

########
# DEV #
########

FROM base as dev
ENV BUNDLE_PATH=/bundle
RUN bundle config set path ${BUNDLE_PATH}
RUN gem install bundler -v 2.4.10

########
# PROD #
########

FROM base as prod
RUN bundle install
RUN RAILS_ENV=production SECRET_KEY_BASE=DUMMY bin/rails assets:precompile
