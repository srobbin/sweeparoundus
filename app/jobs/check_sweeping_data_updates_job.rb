require "csv"
require "json"
require "digest"
require "fileutils"

# Daily, in-season: compares the City's published street sweeping Schedule (CSV)
# and Zones (GeoJSON) against the committed db/data files and, when they differ
# semantically, opens a GitHub PR replacing the canonical file(s). The PR's CI
# run (full RSpec suite) is the validation gate — this job does NOT validate
# in-process. See DEVELOPER.md ("Automated in-season data updates").
#
# Sentry usage mirrors SyncCdotPermitsJob: transient operational failures
# (network, GitHub API, non-404 HTTP) bubble to retry_on -> capture_exception
# on exhaustion. The intentional "data not available yet" conditions are
# rescued inline and reported via capture_message (NOT retried).
class CheckSweepingDataUpdatesJob < ApplicationJob
  queue_as :default

  SEASON_START = [ 3, 20 ].freeze  # Street sweeping starts on April 1; we start checking for the new data shortly before
  SEASON_END   = [ 11, 30 ].freeze # November 30
  TIME_ZONE = "America/Chicago".freeze
  CANDIDATE_DIR = "tmp/sweeping_candidates".freeze

  retry_on StandardError, wait: :polynomially_longer, attempts: 6 do |_job, error|
    Rails.logger.error("[CheckSweepingDataUpdatesJob] All retries exhausted: #{error.class}: #{error.message}")
    Sentry.capture_exception(error)
  end

  def perform
    today = Time.current.in_time_zone(TIME_ZONE).to_date
    unless in_season?(today)
      Rails.logger.info("[CheckSweepingDataUpdatesJob] #{today} is out of season; skipping")
      return
    end

    year = today.year
    config = resolve_config(year)
    return if config.nil?

    metadata = fetch_metadata(config, year)
    return if metadata.nil?

    changes = detect_changes(config, metadata, year)
    if changes.empty?
      Rails.logger.info("[CheckSweepingDataUpdatesJob] No changes for #{year}; nothing to do")
      return
    end

    open_pr(changes, year)
  end

  private

  def in_season?(date)
    season_start = Date.new(date.year, *SEASON_START)
    season_end = Date.new(date.year, *SEASON_END)
    date.between?(season_start, season_end)
  end

  # Availability guard 1: no config for the year (next year's IDs not added).
  def resolve_config(year)
    SweepingDatasets.for(year)
  rescue SweepingDatasets::MissingConfigError => e
    report_unavailable("No dataset config for #{year}: #{e.message}")
    nil
  end

  # Availability guards 2 & 3: dataset not published (404), or metadata is for
  # the wrong year (config still points at last year's dataset).
  def fetch_metadata(config, year)
    metadata = {
      schedule: FetchSweepingDataset.metadata(config.schedule_id),
      zones: FetchSweepingDataset.metadata(config.zones_id)
    }

    metadata.each_value do |meta|
      found_year = year_in_name(meta.name)
      if found_year && found_year != year
        # Intentional all-or-nothing: if EITHER dataset still carries a prior-year
        # name we treat the whole run as "not published yet" and skip both, even if
        # the other dataset already updated. The Schedule and Zones are released
        # together each season, so a lingering prior-year name means the City hasn't
        # finished publishing; we'd rather wait than open a PR that pairs a new-year
        # file with a stale-year one.
        report_unavailable("Dataset '#{meta.name}' (#{meta.id}) is for #{found_year}, expected #{year}")
        return nil
      elsif found_year.nil?
        Rails.logger.warn("[CheckSweepingDataUpdatesJob] Could not parse a year from dataset name #{meta.name.inspect} (#{meta.id}); proceeding — CI is the backstop")
      end
    end

    metadata
  rescue FetchSweepingDataset::NotFound => e
    report_unavailable("Dataset not published yet for #{year}: #{e.message}")
    nil
  end

  def detect_changes(config, metadata, year)
    [
      change_for(:schedule, config.schedule_path,
                 SweepingDatasets.schedule_csv_url(config.schedule_id),
                 "#{year}/schedule.csv", metadata[:schedule]),
      change_for(:zones, config.zones_path,
                 SweepingDatasets.zones_geojson_url(config.zones_id),
                 "#{year}/zones.geojson", metadata[:zones])
    ].compact
  end

  def change_for(kind, repo_path, url, candidate_rel_path, meta)
    dest = Rails.root.join(CANDIDATE_DIR, candidate_rel_path).to_s
    FetchSweepingDataset.download(url, dest: dest)
    candidate = File.binread(dest)

    committed_path = Rails.root.join(repo_path).to_s
    committed = File.exist?(committed_path) ? File.binread(committed_path) : nil

    candidate_canonical = canonicalize(kind, candidate)
    if committed && canonicalize(kind, committed) == candidate_canonical
      Rails.logger.info("[CheckSweepingDataUpdatesJob] #{kind} unchanged for #{repo_path}")
      return nil
    end

    {
      kind: kind,
      path: repo_path,
      content: candidate,
      canonical: candidate_canonical,
      meta: meta,
      summary: summarize(kind, committed, candidate)
    }
  end

  def open_pr(changes, year)
    branch = "data-update/#{year}-#{content_digest(changes)}"
    changed_kinds = changes.map { |c| c[:kind] }.join(", ")
    title = "Street sweeping data update (#{year}): #{changed_kinds}"
    files = changes.map { |c| { path: c[:path], content: c[:content] } }

    OpenCandidateDataPr.new.call(branch: branch, title: title, body: pr_body(changes, year), files: files)
  end

  # --- normalization / comparison ---------------------------------------

  # Compares candidate vs committed by canonical form so the City's export
  # formatting (row order, quoting, line endings, key order) doesn't create
  # false positives.
  def canonicalize(kind, content)
    case kind
    when :schedule then canonical_csv(content)
    when :zones then canonical_geojson(content)
    end
  end

  # Sort the serialized rows (not the raw parsed arrays): CSV.parse yields nil
  # for empty trailing fields, and Array#sort comparing nil <=> String raises.
  # Sorting the to_csv strings is nil-safe and still order-independent.
  def canonical_csv(content)
    CSV.parse(content).map(&:to_csv).sort.join
  end

  def canonical_geojson(content)
    features = JSON.parse(content)["features"] || []
    features.map { |feature| JSON.generate(deep_sort(strip_socrata_meta(feature))) }.sort.join("\n")
  end

  # Socrata's GeoJSON export stamps every feature's properties with internal
  # row metadata (":id", ":version", ":created_at", ":updated_at", ...) that can
  # churn on a republish even when the geographic data is identical. Drop these
  # ":"-prefixed keys before comparing so metadata-only churn doesn't open a
  # no-op PR. Real fields (ward, section, ward_section, globalid, ...) are kept.
  def strip_socrata_meta(feature)
    properties = feature["properties"]
    return feature unless properties.is_a?(Hash)

    feature.merge("properties" => properties.reject { |key, _| key.to_s.start_with?(":") })
  end

  # Recursively sorts Hash keys for a stable representation. Arrays (e.g.
  # coordinate rings, where order is meaningful) keep their order.
  def deep_sort(obj)
    case obj
    when Hash then obj.keys.sort.each_with_object({}) { |k, h| h[k] = deep_sort(obj[k]) }
    when Array then obj.map { |e| deep_sort(e) }
    else obj
    end
  end

  # Deterministic 8-char branch suffix from the changed candidates' canonical
  # forms — stable across runs/processes (Digest, not Ruby's per-process hash),
  # so identical data maps to the same branch (idempotent PRs).
  def content_digest(changes)
    digest = Digest::SHA256.new
    changes.sort_by { |c| c[:path] }.each { |c| digest.update("#{c[:path]}\n#{c[:canonical]}\n") }
    digest.hexdigest[0, 8]
  end

  # --- PR body ----------------------------------------------------------

  def pr_body(changes, year)
    sections = changes.map do |c|
      <<~SECTION.strip
        ### #{c[:kind].to_s.capitalize} — `#{c[:path]}`
        - City `rowsUpdatedAt`: #{c[:meta]&.rows_updated_at || "unknown"}
        #{c[:summary]}
      SECTION
    end

    <<~BODY
      Automated #{year} street sweeping data candidate from the Chicago Data Portal.

      This PR was opened by `we-the-sweeple-data-bot` because the City's published data differs from the committed `db/data/` file(s). **It is opened regardless of validity** — the CI run (full RSpec suite) is the validation gate. A green check means it's safe to merge; a red check shows exactly which data rule failed.

      After merging + deploying, remember the data is not live until the DEVELOPER.md seeding runbook is run.

      #{sections.join("\n\n")}
    BODY
  end

  def summarize(kind, committed, candidate)
    case kind
    when :schedule then summarize_schedule(committed, candidate)
    when :zones then summarize_zones(committed, candidate)
    end
  end

  def summarize_schedule(committed, candidate)
    new_sections = csv_ward_sections(candidate)
    old_sections = committed ? csv_ward_sections(committed) : []
    row_line = "- Rows: #{committed ? csv_data_row_count(committed) : 0} → #{csv_data_row_count(candidate)}"
    [ row_line, ward_section_delta_lines(old_sections, new_sections) ].compact.join("\n")
  end

  def summarize_zones(committed, candidate)
    new_sections = geojson_ward_sections(candidate)
    old_sections = committed ? geojson_ward_sections(committed) : []
    count_line = "- Ward sections: #{old_sections.size} → #{new_sections.size}"
    [ count_line, ward_section_delta_lines(old_sections, new_sections) ].compact.join("\n")
  end

  def ward_section_delta_lines(old_sections, new_sections)
    added = (new_sections - old_sections).sort
    removed = (old_sections - new_sections).sort
    return nil if added.empty? && removed.empty?

    lines = []
    lines << "- Ward sections added (#{added.size}): #{truncate_list(added)}" if added.any?
    lines << "- Ward sections removed (#{removed.size}): #{truncate_list(removed)}" if removed.any?
    lines.join("\n")
  end

  def truncate_list(values, limit = 20)
    return values.join(", ") if values.size <= limit
    "#{values.first(limit).join(", ")}, … (+#{values.size - limit} more)"
  end

  def csv_ward_sections(content)
    CSV.parse(content, headers: true).map { |row| row["WARD SECTION (CONCATENATED)"] }.compact
  end

  def csv_data_row_count(content)
    [ CSV.parse(content).size - 1, 0 ].max
  end

  def geojson_ward_sections(content)
    features = JSON.parse(content)["features"] || []
    features.filter_map { |f| f.dig("properties", "ward_section") }
  end

  # Extracts the first 4-digit run (a year) from a dataset name like
  # "Street Sweeping Schedule - 2026". Returns an Integer, or nil if none.
  def year_in_name(name)
    name.to_s[/\b(\d{4})\b/, 1]&.to_i
  end

  def report_unavailable(message)
    full = "[CheckSweepingDataUpdatesJob] #{message}"
    Rails.logger.error(full)
    Sentry.capture_message(full, level: :error)
  end
end
