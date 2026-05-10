#!/usr/bin/env sh
# PromptHub CLI — curl installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/LeetaoGoooo/PromptHub/main/install.sh | sh
#
# Installs the pre-built binary to ~/.local/bin/prompthub (or /usr/local/bin with sudo).
# Requires macOS 14 (Sonoma) or later.

set -e

REPO="LeetaoGoooo/PromptHub"
BINARY_NAME="prompthub"
INSTALL_DIR="${PROMPTHUB_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${PROMPTHUB_VERSION:-latest}"

# ── helpers ────────────────────────────────────────────────────────────────────

info()    { printf "\033[1;34m[prompthub]\033[0m %s\n" "$*"; }
success() { printf "\033[1;32m[prompthub]\033[0m %s\n" "$*"; }
warn()    { printf "\033[1;33m[prompthub]\033[0m %s\n" "$*" >&2; }
die()     { printf "\033[1;31m[prompthub]\033[0m %s\n" "$*" >&2; exit 1; }

# ── resolve version ────────────────────────────────────────────────────────────

if [ "$VERSION" = "latest" ]; then
  info "Fetching latest release tag..."
  VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
  [ -n "$VERSION" ] || die "Could not determine latest version. Set PROMPTHUB_VERSION=v1.0.0 to pin."
fi

info "Installing PromptHub CLI ${VERSION}"

# ── platform check ─────────────────────────────────────────────────────────────

OS=$(uname -s)
ARCH=$(uname -m)

case "${OS}-${ARCH}" in
  Darwin-arm64)  PLATFORM="macos-arm64" ;;
  Darwin-x86_64) PLATFORM="macos-x86_64" ;;
  *)             die "Unsupported platform: ${OS} ${ARCH}. Only macOS is supported." ;;
esac

# ── download ───────────────────────────────────────────────────────────────────

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${BINARY_NAME}-${PLATFORM}.tar.gz"
TMP_DIR=$(mktemp -d)
TMP_ARCHIVE="${TMP_DIR}/${BINARY_NAME}.tar.gz"

info "Downloading ${DOWNLOAD_URL}"
curl -fsSL --output "$TMP_ARCHIVE" "$DOWNLOAD_URL" \
  || die "Download failed. Check https://github.com/${REPO}/releases for available assets."

# ── verify (optional) ──────────────────────────────────────────────────────────

CHECKSUM_URL="${DOWNLOAD_URL}.sha256"
if curl -fsSL "$CHECKSUM_URL" -o "${TMP_ARCHIVE}.sha256" 2>/dev/null; then
  EXPECTED=$(awk '{print $1}' "${TMP_ARCHIVE}.sha256")
  ACTUAL=$(shasum -a 256 "$TMP_ARCHIVE" | awk '{print $1}')
  if [ "$EXPECTED" != "$ACTUAL" ]; then
    die "SHA-256 checksum mismatch. Expected ${EXPECTED}, got ${ACTUAL}. Aborting."
  fi
  info "Checksum verified."
else
  warn "No checksum file found — skipping verification."
fi

# ── extract & install ──────────────────────────────────────────────────────────

tar -xzf "$TMP_ARCHIVE" -C "$TMP_DIR"
rm -f "$TMP_ARCHIVE"

EXTRACTED_BINARY=$(find "$TMP_DIR" -type f -name "$BINARY_NAME" | head -1)
[ -n "$EXTRACTED_BINARY" ] || die "Binary '${BINARY_NAME}' not found in archive."

mkdir -p "$INSTALL_DIR"
install -m 755 "$EXTRACTED_BINARY" "${INSTALL_DIR}/${BINARY_NAME}"
rm -rf "$TMP_DIR"

# ── PATH hint ─────────────────────────────────────────────────────────────────

success "Installed to ${INSTALL_DIR}/${BINARY_NAME}"

if ! command -v "$BINARY_NAME" >/dev/null 2>&1; then
  warn "  ${INSTALL_DIR} is not in your PATH."
  warn "  Add it to your shell profile:"
  case "${SHELL}" in
    */zsh)  warn "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc" ;;
    */bash) warn "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc" ;;
    *)      warn "    export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
  esac
fi

# ── verify ────────────────────────────────────────────────────────────────────

info "Running: prompthub agent doctor"
"${INSTALL_DIR}/${BINARY_NAME}" agent doctor || true

success "Done! Run 'prompthub --help' to get started."
