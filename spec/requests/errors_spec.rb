require "rails_helper"

RSpec.describe "Errors", type: :request do
  describe "an unrouted path" do
    # In test/development Rails shows its detailed debug page for unhandled
    # exceptions. Flip these flags so the request takes the production path
    # (`config.exceptions_app` -> routes -> ErrorsController) instead.
    around do |example|
      config = Rails.application.env_config
      original = config.slice(
        "action_dispatch.show_exceptions",
        "action_dispatch.show_detailed_exceptions"
      )
      config["action_dispatch.show_exceptions"] = :all
      config["action_dispatch.show_detailed_exceptions"] = false
      example.run
      config.merge!(original)
    end

    it "renders the friendly not-found page for HTML requests" do
      get "/totally-bogus-path"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("We couldn't find that page.")
      expect(response.body).to include('action="/search/"')
    end

    it "returns a bare 404 for non-HTML requests" do
      get "/totally-bogus-path.json"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to be_blank
    end

    # Scanners request `.js` URLs to probe for embeddable scripts. A bare
    # `head :not_found` mirrors the requested format, stamping the empty body
    # with `Content-Type: text/javascript`. Rails' cross-origin JS forgery
    # check then logs a "Security warning: an embedded <script> tag..." warning
    # (captured by Sentry) and raises InvalidCrossOriginRequest. Responding as
    # text/plain keeps the 404 clean and silent.
    it "returns a bare 404 for .js requests without tripping cross-origin JS protection" do
      expect(Rails.logger).not_to receive(:warn)

      get "/totally-bogus-path.js"

      expect(response).to have_http_status(:not_found)
      expect(response.media_type).to eq("text/plain")
      expect(response.body).to be_blank
    end
  end

  # A routed action that raises RecordNotFound (e.g. an expired/unknown area
  # slug) is handled by `ApplicationController#render_not_found` via `rescue_from`
  # -- a separate code path from the unrouted `exceptions_app` dispatch above.
  describe "a routed action that raises RecordNotFound" do
    it "renders the friendly not-found page for HTML requests" do
      get "/areas/does-not-exist"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("We couldn't find that page.")
    end

    # Same cross-origin JS forgery concern as the unrouted path: a bare
    # `head :not_found` would answer a `.js` probe as text/javascript, logging a
    # "Security warning..." and raising InvalidCrossOriginRequest.
    it "returns a bare 404 for .js requests without tripping cross-origin JS protection" do
      expect(Rails.logger).not_to receive(:warn)

      get "/areas/does-not-exist.js"

      expect(response).to have_http_status(:not_found)
      expect(response.media_type).to eq("text/plain")
      expect(response.body).to be_blank
    end
  end

  # 422/500 keep their existing static `public/*.html` pages. A direct GET would
  # be intercepted by the static file server, so dispatch through the router the
  # same way `config.exceptions_app` does for a real exception.
  describe "static error pages dispatched via the router" do
    def dispatch(path)
      env = Rack::MockRequest.env_for(path, "REQUEST_METHOD" => "GET")
      status, _headers, body = Rails.application.routes.call(env)
      buffer = +""
      body.each { |chunk| buffer << chunk }
      [ status, buffer ]
    end

    it "serves the static 422 page" do
      status, body = dispatch("/422")

      expect(status).to eq(422)
      expect(body).to include("The change you wanted was rejected.")
    end

    it "serves the static 500 page" do
      status, body = dispatch("/500")

      expect(status).to eq(500)
      expect(body).to include("We're sorry, but something went wrong.")
    end
  end
end
