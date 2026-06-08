# frozen_string_literal: true

require "rails_helper"

RSpec.describe OpenCandidateDataPr, type: :service do
  let(:client) { instance_double(Octokit::Client) }
  subject(:service) { described_class.new(client: client) }

  let(:branch) { "data-update/2026-abc12345" }
  let(:files) { [ { path: "db/data/Street_Sweeping_Schedule_-_2026.csv", content: "WARD,SECTION\n01,01\n" } ] }
  let(:repo) { "srobbin/sweeparoundus" }

  def stub_branch_missing
    allow(client).to receive(:ref).with(repo, "heads/#{branch}").and_raise(Octokit::NotFound.new)
  end

  context "when the candidate branch does not yet exist" do
    before do
      stub_branch_missing
      allow(client).to receive(:ref).with(repo, "heads/main").and_return(double(object: double(sha: "base-sha")))
      allow(client).to receive(:commit).with(repo, "base-sha").and_return(double(commit: double(tree: double(sha: "base-tree-sha"))))
      allow(client).to receive(:create_blob).and_return("blob-sha")
      allow(client).to receive(:create_tree).and_return(double(sha: "new-tree-sha"))
      allow(client).to receive(:create_commit).and_return(double(sha: "commit-sha"))
      allow(client).to receive(:create_ref)
      allow(client).to receive(:create_pull_request).and_return(double(number: 42))
    end

    it "creates a blob/tree/commit/ref and opens a PR" do
      pr = service.call(branch: branch, title: "Update", body: "body", files: files)

      expect(client).to have_received(:create_blob).with(repo, Base64.strict_encode64(files.first[:content]), "base64")
      expect(client).to have_received(:create_tree).with(
        repo,
        [ { path: files.first[:path], mode: "100644", type: "blob", sha: "blob-sha" } ],
        base_tree: "base-tree-sha"
      )
      expect(client).to have_received(:create_commit).with(repo, "Update", "new-tree-sha", "base-sha")
      expect(client).to have_received(:create_ref).with(repo, "refs/heads/#{branch}", "commit-sha")
      expect(client).to have_received(:create_pull_request).with(repo, "main", branch, "Update", "body")
      expect(pr.number).to eq(42)
    end
  end

  context "when the branch already exists (open PR under review or dismissed)" do
    before do
      allow(client).to receive(:ref).with(repo, "heads/#{branch}").and_return(double(object: double(sha: "existing-sha")))
      allow(client).to receive(:pull_requests).and_return([ double(number: 7, state: "open") ])
      allow(client).to receive(:create_ref)
      allow(client).to receive(:create_pull_request)
    end

    it "skips without creating a ref or PR and returns nil" do
      expect(service.call(branch: branch, title: "Update", body: "body", files: files)).to be_nil
      expect(client).not_to have_received(:create_ref)
      expect(client).not_to have_received(:create_pull_request)
    end
  end

  context "when the branch exists but has no PR (partial failure on a prior run)" do
    before do
      allow(client).to receive(:ref).with(repo, "heads/#{branch}").and_return(double(object: double(sha: "orphan-sha")))
      allow(client).to receive(:pull_requests).and_return([])
      allow(client).to receive(:create_blob)
      allow(client).to receive(:create_tree)
      allow(client).to receive(:create_ref)
      allow(client).to receive(:create_pull_request).and_return(double(number: 99))
    end

    it "opens the missing PR against the existing branch without recreating the ref" do
      pr = service.call(branch: branch, title: "Update", body: "body", files: files)

      expect(client).not_to have_received(:create_blob)
      expect(client).not_to have_received(:create_tree)
      expect(client).not_to have_received(:create_ref)
      expect(client).to have_received(:create_pull_request).with(repo, "main", branch, "Update", "body")
      expect(pr.number).to eq(99)
    end
  end

  it "raises when no files are provided" do
    expect { service.call(branch: branch, title: "t", body: "b", files: []) }
      .to raise_error(OpenCandidateDataPr::Error)
  end

  describe ".app_installation_client" do
    let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }

    around do |example|
      previous = ENV.values_at("GITHUB_APP_ID", "GITHUB_APP_INSTALLATION_ID", "GITHUB_APP_PRIVATE_KEY")
      ENV["GITHUB_APP_ID"] = "4000424"
      ENV["GITHUB_APP_INSTALLATION_ID"] = "138932483"
      ENV["GITHUB_APP_PRIVATE_KEY"] = Base64.strict_encode64(rsa_key.to_pem)
      example.run
    ensure
      ENV["GITHUB_APP_ID"], ENV["GITHUB_APP_INSTALLATION_ID"], ENV["GITHUB_APP_PRIVATE_KEY"] = previous
    end

    it "mints an installation token via a signed app JWT and returns a token-auth client" do
      app_client = instance_double(Octokit::Client)
      token_client = instance_double(Octokit::Client)
      captured_jwt = nil

      allow(Octokit::Client).to receive(:new) do |bearer_token: nil, access_token: nil|
        if bearer_token
          captured_jwt = bearer_token
          app_client
        else
          expect(access_token).to eq("install-token")
          token_client
        end
      end
      allow(app_client).to receive(:create_app_installation_access_token)
        .with("138932483").and_return(double(token: "install-token"))

      result = described_class.app_installation_client

      expect(result).to be(token_client)

      claims = JWT.decode(captured_jwt, rsa_key.public_key, true, algorithm: "RS256").first
      expect(claims["iss"]).to eq("4000424")
      expect(claims["exp"] - claims["iat"]).to eq(OpenCandidateDataPr::JWT_EXPIRY_SECONDS + 60)
    end
  end
end
