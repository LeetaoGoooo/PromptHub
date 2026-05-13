class Ph < Formula
  desc "PromptHub CLI for exported prompts and agent skills"
  homepage "https://github.com/LeetaoGoooo/PromptHub"
  license "MIT"

  source_url = ENV["HOMEBREW_PROMPTHUB_SOURCE_URL"]
  source_sha = ENV["HOMEBREW_PROMPTHUB_SOURCE_SHA256"]

  if source_url && source_sha
    url source_url
    sha256 source_sha
    version "0.0.0-local"
  else
    head "https://github.com/LeetaoGoooo/PromptHub.git", branch: "main"
  end

  def install
    system "swift", "build", "--disable-sandbox", "--package-path", "PromptHubCLI", "-c", "release", "--product", "ph"

    bin_path = Dir[buildpath/"PromptHubCLI/.build/*/release/ph"].first
    raise "Unable to locate built ph binary" if bin_path.nil?

    bin.install bin_path => "ph"
  end

  test do
    assert_match "USAGE: ph <subcommand>", shell_output("#{bin}/ph --help")
  end
end