class Ph < Formula
  desc "PromptHub CLI for exported prompts and agent skills"
  homepage "https://github.com/DoSomeForFun/PromptHub"
  license "MIT"

  # ----------------------------------------------------------------------
  # Stable release coordinates.
  #
  # Bump STABLE_VERSION and STABLE_ARM64_SHA whenever a new `ph-vX.Y.Z`
  # release is published. See docs/cli-release.md for the exact procedure.
  # The sentinel SHA below is used until the first stable release exists;
  # in that state, end users should install via `--HEAD` or wait for the
  # tagged release. The release workflow always installs through the env
  # var override path described below before publishing, so the sentinel
  # never breaks the release pipeline.
  # ----------------------------------------------------------------------
  STABLE_VERSION = "0.1.0".freeze
  STABLE_ARM64_URL =
    "https://github.com/DoSomeForFun/PromptHub/releases/download/ph-v#{STABLE_VERSION}/ph-macos-arm64.tar.gz".freeze
  STABLE_ARM64_SHA = "0000000000000000000000000000000000000000000000000000000000000000".freeze

  # ----------------------------------------------------------------------
  # CI / local smoke override.
  #
  # When HOMEBREW_PROMPTHUB_BOTTLE_URL + _SHA256 are set, the formula
  # installs from that prebuilt-binary archive instead of the stable
  # release URL. This is used by:
  #   * .github/workflows/prompthub-cli-release.yml (smoke before publish)
  #   * tools/homebrew/verify-formula.sh (local validation)
  # ----------------------------------------------------------------------
  override_url = ENV["HOMEBREW_PROMPTHUB_BOTTLE_URL"]
  override_sha = ENV["HOMEBREW_PROMPTHUB_BOTTLE_SHA256"]
  override_version = ENV["HOMEBREW_PROMPTHUB_BOTTLE_VERSION"]

  if override_url && override_sha
    url override_url
    sha256 override_sha
    version override_version || "#{STABLE_VERSION}-local"
  else
    url STABLE_ARM64_URL
    sha256 STABLE_ARM64_SHA
    version STABLE_VERSION
  end

  head "https://github.com/DoSomeForFun/PromptHub.git", branch: "main"

  depends_on :macos
  depends_on arch: :arm64

  def install
    # Stable / bottle install: archive contains a single `ph` binary.
    prebuilt = buildpath/"ph"
    if prebuilt.file?
      bin.install prebuilt
      return
    end

    # HEAD install: build from source. Requires swift toolchain (Xcode).
    system "swift", "build",
           "--disable-sandbox",
           "--package-path", "PromptHubCLI",
           "-c", "release",
           "--product", "ph"

    bin_path = Dir[buildpath/"PromptHubCLI/.build/*/release/ph"].first
    raise "Unable to locate built ph binary" if bin_path.nil?

    bin.install bin_path => "ph"
  end

  test do
    assert_match "USAGE: ph <subcommand>", shell_output("#{bin}/ph --help")
    assert_match "ph prompt", shell_output("#{bin}/ph --help")
    assert_match "ph skill", shell_output("#{bin}/ph --help")
  end
end
