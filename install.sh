#!/usr/bin/env sh
set -e

REPO="raphaelbarbosaqwerty/shazam-cli"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

# Detect OS
OS="$(uname -s)"
case "$OS" in
  Darwin) OS_NAME="macos" ;;
  Linux)  OS_NAME="linux" ;;
  *)
    echo "Error: Unsupported operating system: $OS"
    exit 1
    ;;
esac

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
  arm64|aarch64) ARCH_NAME="arm64" ;;
  x86_64)        ARCH_NAME="x86_64" ;;
  *)
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "Detected platform: ${OS_NAME}-${ARCH_NAME}"
echo ""

# Determine install directory
if [ -d "${HOME}/.local/bin" ] || [ "$OS_NAME" = "linux" ]; then
  INSTALL_DIR="${HOME}/.local/bin"
else
  INSTALL_DIR="${HOME}/bin"
fi
mkdir -p "$INSTALL_DIR"

# Fetch latest release info
echo "Fetching latest release..."
RELEASE_JSON="$(curl -fsSL "$API_URL")"

# Extract the download URL for the matching tarball
TARBALL_URL="$(echo "$RELEASE_JSON" | grep -o "\"browser_download_url\": *\"[^\"]*shazam-[^\"]*-${OS_NAME}-${ARCH_NAME}\\.tar\\.gz\"" | head -1 | sed 's/.*"browser_download_url": *"\([^"]*\)"/\1/')"

if [ -z "$TARBALL_URL" ]; then
  echo "Error: No release found for ${OS_NAME}-${ARCH_NAME}"
  echo "Check available releases at: https://github.com/${REPO}/releases"
  exit 1
fi

VERSION="$(echo "$RELEASE_JSON" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)"/\1/')"
echo "Latest version: ${VERSION}"
echo "Downloading ${TARBALL_URL}..."

# Download and extract
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

curl -fsSL "$TARBALL_URL" -o "${TMPDIR}/shazam.tar.gz"
tar xzf "${TMPDIR}/shazam.tar.gz" -C "$TMPDIR"

# Install binaries
cp "${TMPDIR}/shazam" "${INSTALL_DIR}/shazam"
cp "${TMPDIR}/shazam-tui" "${INSTALL_DIR}/shazam-tui"
chmod +x "${INSTALL_DIR}/shazam" "${INSTALL_DIR}/shazam-tui"

echo ""
echo "Shazam ${VERSION} installed successfully!"
echo ""
echo "  shazam     -> ${INSTALL_DIR}/shazam"
echo "  shazam-tui -> ${INSTALL_DIR}/shazam-tui"
echo ""

# Check if install dir is in PATH
case ":$PATH:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    echo "Add ${INSTALL_DIR} to your PATH:"
    echo ""
    echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
    echo ""
    echo "Add the line above to your ~/.bashrc or ~/.zshrc to make it permanent."
    echo ""
    ;;
esac

echo "Run 'shazam --help' to get started."
