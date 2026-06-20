#!/usr/bin/env bash
#
# tools/homebrew/verify-formula.sh
#
# Local mirror of the release-workflow smoke step. Builds the ph release
# binary, packages it into the same archive layout the release publishes,
# then installs Formula/ph.rb through a throw-away local Homebrew tap with
# the HOMEBREW_PROMPTHUB_BOTTLE_* env overrides pointing at the local
# archive.
#
# Prerequisites: Homebrew on macOS Apple Silicon and the Xcode toolchain.
#
# Exit codes:
#   0   formula installed and `ph --help` ran from the brew prefix.
#   1   any prerequisite, build, archive, install, or smoke step failed.
#
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "brew not found on PATH; install Homebrew before running this script." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "swift not found on PATH; install the Xcode toolchain before running this script." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

DIST_DIR="$REPO_ROOT/build/homebrew-verify"
ARCHIVE_PATH="$DIST_DIR/ph-macos-arm64.tar.gz"
TAP_NAME="local/prompthub-verify"

cleanup() {
  brew uninstall --force ph >/dev/null 2>&1 || true
  brew untap "$TAP_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$DIST_DIR/archive"

echo "==> Building release ph binary"
swift build --package-path PromptHubCLI -c release --product ph

BIN_PATH="$(swift build --package-path PromptHubCLI -c release --product ph --show-bin-path)"
cp "$BIN_PATH/ph" "$DIST_DIR/archive/ph"
tar -C "$DIST_DIR/archive" -czf "$ARCHIVE_PATH" ph

ARCHIVE_SHA256="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
ARCHIVE_VERSION="${PROMPTHUB_BOTTLE_VERSION:-0.0.0-local}"

echo "==> Setting up throwaway tap $TAP_NAME"
brew untap "$TAP_NAME" >/dev/null 2>&1 || true
brew tap-new "$TAP_NAME"
TAP_REPO="$(brew --repository "$TAP_NAME")"
cp Formula/ph.rb "$TAP_REPO/Formula/ph.rb"

export HOMEBREW_PROMPTHUB_BOTTLE_URL="file://$ARCHIVE_PATH"
export HOMEBREW_PROMPTHUB_BOTTLE_SHA256="$ARCHIVE_SHA256"
export HOMEBREW_PROMPTHUB_BOTTLE_VERSION="$ARCHIVE_VERSION"

echo "==> Installing $TAP_NAME/ph from local archive"
brew install "$TAP_NAME/ph"

INSTALLED_PATH="$(brew --prefix "$TAP_NAME/ph")/bin/ph"
if [[ ! -x "$INSTALLED_PATH" ]]; then
  echo "Homebrew install did not produce ph at $INSTALLED_PATH" >&2
  exit 1
fi

echo "==> Smoke testing installed ph"
"$INSTALLED_PATH" --help | head -1
brew test "$TAP_NAME/ph"

echo "==> OK: ph installed via Homebrew from local archive ($ARCHIVE_SHA256)"
