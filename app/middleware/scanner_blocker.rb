# frozen_string_literal: true

class ScannerBlocker
  BLOCKED_PATHS = %w[
    /.env
    /.git/
    /.svn/
    /.htaccess
    /.htpasswd
    /.ds_store
    /wp-admin
    /wp-login.php
    /wp-content
    /wp-includes
    /xmlrpc.php
    /phpinfo.php
    /phpmyadmin
    /admin.php
    /server-status
    /server-info
    /cgi-bin/
    /logs/
    /backup/
    /dump/
  ].freeze

  BLOCKED_EXTENSIONS = %w[
    .php .log .sql .bak .old .orig .swp .sav
    .conf .cfg .ini .env .tar .gz .zip
  ].freeze

  NOT_FOUND_HEADERS = { "content-type" => "text/plain", "connection" => "close" }.freeze
  NOT_FOUND_BODY = [ "Not Found" ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env[Rack::PATH_INFO].to_s.downcase

    return [ 404, NOT_FOUND_HEADERS.dup, NOT_FOUND_BODY ] if blocked_path?(path) || blocked_extension?(path)

    @app.call(env)
  end

  private

  def blocked_path?(path)
    BLOCKED_PATHS.any? { |prefix| path.start_with?(prefix) }
  end

  def blocked_extension?(path)
    BLOCKED_EXTENSIONS.any? { |ext| path.end_with?(ext) }
  end
end
