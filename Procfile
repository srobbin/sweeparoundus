web: bundle exec puma -C config/puma.rb
sidekiq: RAILS_MAX_THREADS=${SIDEKIQ_RAILS_MAX_THREADS:-5} bundle exec sidekiq -C config/sidekiq.yml
release: bin/rails db:migrate
