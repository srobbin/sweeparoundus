require "octokit"
require "jwt"
require "base64"
require "openssl"

# Opens (or skips, idempotently) a GitHub PR that replaces canonical db/data
# file(s) with a candidate export. Commits via the Git Data API (blob/tree/
# commit/ref) because the Zones GeoJSON (~4.7MB) exceeds the Contents API's
# 1MB limit. Authenticates as the "We The Sweeple Data Bot" GitHub App.
#
#   OpenCandidateDataPr.new.call(
#     branch: "data-update/2026-ab12cd34",
#     title:  "Street sweeping data update (2026)",
#     body:   "...",
#     files:  [{ path: "db/data/...csv", content: "<bytes>" }, ...]
#   )
#
# Returns the PR (Sawyer::Resource) it created, or nil when it skipped because
# the branch already has a PR (an open PR under review, or a previously
# closed-without-merge candidate that was deliberately dismissed — delete the
# branch to force a re-open). If the branch exists with NO PR at all — almost
# always a partial failure on a prior run that created the ref but never landed
# the PR — it opens the missing PR rather than silently skipping forever.
class OpenCandidateDataPr
  REPO = "srobbin/sweeparoundus"
  BASE_BRANCH = "main"
  # GitHub caps the app JWT's lifetime at 10 minutes; 9 leaves headroom for clock skew.
  JWT_EXPIRY_SECONDS = 540

  Error = Class.new(StandardError)

  def initialize(client: self.class.app_installation_client)
    @client = client
  end

  def call(branch:, title:, body:, files:)
    raise Error, "files cannot be empty" if files.blank?

    if branch_exists?(branch)
      existing = existing_pull_request(branch)
      if existing
        Rails.logger.info("[OpenCandidateDataPr] Branch #{branch} already has " \
                          "PR ##{existing.number} (#{existing.state}); skipping")
        return nil
      end

      # Orphan branch (ref exists, no PR): the candidate commit is already on the
      # branch, so just open the PR. Skipping here would suppress this candidate
      # until someone manually deleted the branch.
      Rails.logger.warn("[OpenCandidateDataPr] Branch #{branch} exists with no PR; opening one")
      return open_pull_request(branch, title, body)
    end

    base_sha = @client.ref(REPO, "heads/#{BASE_BRANCH}").object.sha
    base_tree_sha = @client.commit(REPO, base_sha).commit.tree.sha

    tree_entries = files.map do |file|
      blob_sha = @client.create_blob(REPO, Base64.strict_encode64(file[:content]), "base64")
      { path: file[:path], mode: "100644", type: "blob", sha: blob_sha }
    end

    new_tree = @client.create_tree(REPO, tree_entries, base_tree: base_tree_sha)
    commit = @client.create_commit(REPO, title, new_tree.sha, base_sha)
    @client.create_ref(REPO, "refs/heads/#{branch}", commit.sha)

    open_pull_request(branch, title, body)
  end

  # Builds a short-lived client authenticated as the GitHub App installation.
  def self.app_installation_client
    app_id = ENV.fetch("GITHUB_APP_ID")
    installation_id = ENV.fetch("GITHUB_APP_INSTALLATION_ID")
    private_key = OpenSSL::PKey::RSA.new(Base64.decode64(ENV.fetch("GITHUB_APP_PRIVATE_KEY")))

    now = Time.now.to_i
    jwt = JWT.encode({ iat: now - 60, exp: now + JWT_EXPIRY_SECONDS, iss: app_id }, private_key, "RS256")

    app_client = Octokit::Client.new(bearer_token: jwt)
    token = app_client.create_app_installation_access_token(installation_id).token
    Octokit::Client.new(access_token: token)
  end

  private

  def open_pull_request(branch, title, body)
    pr = @client.create_pull_request(REPO, BASE_BRANCH, branch, title, body)
    Rails.logger.info("[OpenCandidateDataPr] Opened PR ##{pr.number} on branch #{branch}")
    pr
  end

  def branch_exists?(branch)
    @client.ref(REPO, "heads/#{branch}")
    true
  rescue Octokit::NotFound
    false
  end

  def existing_pull_request(branch)
    owner = REPO.split("/").first
    @client.pull_requests(REPO, head: "#{owner}:#{branch}", state: "all").first
  end
end
