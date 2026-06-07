require "rails_helper"
require "net/http"

RSpec.describe "FAQ", type: :request do
  # External URLs the FAQ links out to. The presence specs assert these strings
  # appear in the rendered page; the (opt-in) liveness specs actually fetch them.
  EXPECTED_EXTERNAL_URLS = [
    "https://www.chicago.gov/sweepertracker",
    "https://www.chicago.gov/city/en/depts/streets/provdrs/streets_san/svcs.html",
    "https://www.chicago.gov/city/en/depts/other/dataset/wards.html",
    "https://data.cityofchicago.org/browse?category=Sanitation",
    "https://github.com/srobbin/sweeparoundus#api"
  ].freeze

  describe "GET /faq" do
    it "renders the page" do
      get faq_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the three section headings" do
      get faq_path

      headings = Nokogiri::HTML(response.body).css("h2").map { |h| h.text.strip }

      expect(headings).to include(
        "Notifications & Subscriptions",
        "Schedule Accuracy & Verification",
        "About the Site"
      )
    end

    it "includes the expected external links" do
      get faq_path

      hrefs = Nokogiri::HTML(response.body).css("a[href]").map { |a| a["href"] }

      aggregate_failures do
        EXPECTED_EXTERNAL_URLS.each do |url|
          expect(hrefs).to include(url), "expected FAQ to link to #{url}"
        end
      end
    end
  end

  # Liveness check: actually fetches every external link on the page and confirms
  # it resolves. This hits the public internet, so it is OPT-IN to keep the normal
  # suite fast and deterministic (third-party outages should not fail CI).
  #
  #   CHECK_EXTERNAL_LINKS=1 bundle exec rspec spec/requests/faq_spec.rb
  #
  describe "external links resolve", :external do
    REQUEST_TIMEOUT = 10
    MAX_REDIRECTS = 5
    MAX_ATTEMPTS = 3
    RETRY_DELAY = 3
    BROWSER_USER_AGENT =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36".freeze

    around do |example|
      unless ENV["CHECK_EXTERNAL_LINKS"]
        skip "set CHECK_EXTERNAL_LINKS=1 to run external link liveness checks"
      end

      WebMock.allow_net_connect!
      example.run
      WebMock.disable_net_connect!
    end

    it "returns a non-error status for every external link on the page" do
      get faq_path

      external_urls = Nokogiri::HTML(response.body)
        .css("a[href^='http']")
        .map { |a| a["href"] }
        .uniq

      expect(external_urls).not_to be_empty

      aggregate_failures do
        external_urls.each do |url|
          status = fetch_status(url)
          expect(status).to be_between(200, 399),
            "expected #{url} to resolve, got #{status || 'no response'}"
        end
      end
    end

    # Follows redirects and retries transient failures (timeouts, 5xx, 429) with a
    # short wait, so a momentary blip doesn't fail the check. Returns the final
    # HTTP status code, or nil if it never got a response.
    def fetch_status(url, redirects_left: MAX_REDIRECTS, attempt: 1)
      uri = URI(url)
      uri.fragment = nil

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                 open_timeout: REQUEST_TIMEOUT, read_timeout: REQUEST_TIMEOUT) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = BROWSER_USER_AGENT
        http.request(request)
      end

      code = response.code.to_i

      if response.is_a?(Net::HTTPRedirection) && response["location"] && redirects_left.positive?
        location = URI.join(uri, response["location"]).to_s
        return fetch_status(location, redirects_left: redirects_left - 1, attempt: attempt)
      end

      if (code >= 500 || code == 429) && attempt < MAX_ATTEMPTS
        sleep(RETRY_DELAY * attempt)
        return fetch_status(url, redirects_left: redirects_left, attempt: attempt + 1)
      end

      code
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, SocketError => e
      if attempt < MAX_ATTEMPTS
        sleep(RETRY_DELAY * attempt)
        retry
      end
      warn "[faq_spec] #{url} failed after #{MAX_ATTEMPTS} attempts: #{e.class}: #{e.message}"
      nil
    end
  end
end
