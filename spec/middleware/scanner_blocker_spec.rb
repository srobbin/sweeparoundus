require "rails_helper"

RSpec.describe ScannerBlocker do
  let(:app) { ->(env) { [ 200, { "content-type" => "text/html" }, [ "OK" ] ] } }
  let(:middleware) { described_class.new(app) }

  def request_for(path)
    Rack::MockRequest.env_for(path)
  end

  describe "blocked paths" do
    %w[
      /.env
      /.git/config
      /.git/HEAD
      /.svn/entries
      /.htaccess
      /.htpasswd
      /.DS_Store
      /wp-admin
      /wp-admin/install.php
      /wp-login.php
      /wp-content/uploads
      /wp-includes/js
      /xmlrpc.php
      /phpinfo.php
      /phpmyadmin
      /admin.php
      /server-status
      /server-info
      /cgi-bin/test
      /logs/error.log
      /backup/db.sql
      /dump/latest
    ].each do |path|
      it "blocks #{path}" do
        status, = middleware.call(request_for(path))
        expect(status).to eq(404)
      end
    end
  end

  describe "blocked extensions" do
    %w[
      /app.php
      /debug.log
      /dump.sql
      /site.bak
      /config.old
      /data.orig
      /notes.swp
      /backup.tar
      /archive.gz
      /files.zip
      /settings.conf
      /database.cfg
      /app.ini
      /secrets.env
    ].each do |path|
      it "blocks #{path}" do
        status, = middleware.call(request_for(path))
        expect(status)
          .to eq(404),
              "expected #{path} to be blocked (404) but got #{status}"
      end
    end
  end

  describe "case insensitivity" do
    it "blocks uppercase variants" do
      status, = middleware.call(request_for("/WP-ADMIN"))
      expect(status).to eq(404)
    end

    it "blocks mixed-case variants" do
      status, = middleware.call(request_for("/Logs/Error.LOG"))
      expect(status).to eq(404)
    end
  end

  describe "legitimate paths" do
    %w[
      /
      /areas
      /areas/12345
      /sweeps
      /api/v1/sweeps
      /users/sign_in
      /subscriptions
      /assets/application.css
      /assets/application.js
    ].each do |path|
      it "allows #{path}" do
        status, = middleware.call(request_for(path))
        expect(status).to eq(200)
      end
    end
  end

  describe "response format" do
    it "returns plain text 'Not Found' for blocked paths" do
      status, headers, body = middleware.call(request_for("/.env"))

      expect(status).to eq(404)
      expect(headers["content-type"]).to eq("text/plain")
      expect(body).to eq([ "Not Found" ])
    end
  end
end
