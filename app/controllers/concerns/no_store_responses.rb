module NoStoreResponses
  extend ActiveSupport::Concern

  # Default dynamic responses (HTML, Turbo Streams, JSON) to `no-store`
  # so browsers and shared caches don't retain pages with CSRF tokens,
  # JWT-bearing links, session-derived content, or other personalized data.
  #
  # To opt an action out of `no-store`:
  #   - For a fixed TTL, call `expires_in N.minutes, public: true` inside
  #     the action — `expires_in` replaces `Cache-Control` outright.
  #   - For conditional GETs via `stale?` / `fresh_when`, also
  #     `skip_before_action :set_cache_control_headers` for that action /
  #     format. Those helpers only add `ETag` / `Last-Modified`; they do
  #     not clear an already-set `Cache-Control: no-store`.
  included do
    before_action :set_cache_control_headers
  end

  private

  def set_cache_control_headers
    response.headers["Cache-Control"] = "no-store, max-age=0, private"
  end
end
