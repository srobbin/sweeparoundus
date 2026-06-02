module NoStoreResponses
  extend ActiveSupport::Concern

  # Adds `Cache-Control: no-store` to dynamic responses (HTML, Turbo Streams,
  # JSON) so browsers and shared caches never save them. These pages can hold
  # CSRF tokens, JWT links, or other per-user data that must not be reused for
  # someone else (or shown again to the same person later).
  #
  # We set this via `response.cache_control` (a hash Rails reads) instead of
  # writing the `Cache-Control` header string ourselves. When an action uses
  # `respond_to` to serve more than one format, Rails rebuilds that header from
  # the hash just before sending the response. A header we wrote by hand would
  # get overwritten by Rails' default, silently losing our `no-store`.
  #
  # Some actions should NOT be `no-store`. For example, the `.ics` calendar feed
  # uses conditional GETs (`stale?` / `fresh_when`) so clients can re-check with
  # an ETag instead of downloading it every time. Opt those formats out in the
  # controller:
  #
  #   no_store_skip_formats :ics
  #
  # We skip by format, not by action, because one action can serve several
  # formats. `skip_before_action` only works per action, so it couldn't say
  # "skip `.ics` but keep `no-store` for `.html`" on the same action.
  included do
    before_action :set_cache_control_headers
    class_attribute :no_store_excluded_formats, instance_writer: false, default: []
  end

  class_methods do
    def no_store_skip_formats(*formats)
      self.no_store_excluded_formats = formats.map(&:to_sym)
    end
  end

  private

  def set_cache_control_headers
    return if no_store_excluded_formats.include?(request.format.symbol)

    response.cache_control.replace(no_store: true, private: true)
  end
end
