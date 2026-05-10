# typed: false
# frozen_string_literal: true

# PromptHub CLI — Homebrew formula
# Place this file in your tap repository at:
#   homebrew-tap/Formula/prompthub.rb
#
# To publish:
#   1. Create a GitHub repo named "homebrew-tap" under your GitHub org/user
#   2. Copy this file to homebrew-tap/Formula/prompthub.rb
#   3. Users can then install via:
#        brew tap LeetaoGoooo/tap
#        brew install LeetaoGoooo/tap/prompthub
#
# To generate SHA-256 for a release archive:
#   curl -sL <archive-url> | shasum -a 256

class Prompthub < Formula
  desc "PromptHub CLI — agent access to your local prompt and skill assets"
  homepage "https://github.com/LeetaoGoooo/PromptHub"
  # TODO: Update url and sha256 when you publish a release
  url "https://github.com/LeetaoGoooo/PromptHub/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256_OF_RELEASE_ARCHIVE"
  license "MIT"
  head "https://github.com/LeetaoGoooo/PromptHub.git", branch: "main"

  # Build from source using Swift Package Manager
  depends_on xcode: ["15.0", :build]
  depends_on :macos => :sonoma

  def install
    # Build only the CLI package (not the full Xcode app)
    system "swift", "build",
           "--package-path", "PromptHubCLI",
           "--configuration", "release",
           "--disable-sandbox"
    bin.install "PromptHubCLI/.build/release/prompthub"
  end

  def caveats
    <<~EOS
      PromptHub CLI reads assets exported by the PromptHub macOS app from:
        ~/.prompthub/prompts/
        ~/.prompthub/skills/

      Open the PromptHub app at least once to populate your asset library.
      Then verify the setup with:
        prompthub agent doctor

      QUICK START
        prompthub prompt list
        prompthub skill list
        prompthub prompt render <name> --var key=value
    EOS
  end

  test do
    assert_match "prompthub", shell_output("#{bin}/prompthub --help")
    assert_match "agent", shell_output("#{bin}/prompthub --help")
  end
end
