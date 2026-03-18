#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/bin"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "⚡ Building Shazam..."
echo ""

# ── Step 1: Build Rust TUI binary ─────────────────────────
echo "  [1/3] Building Rust TUI (shazam-tui)..."
if command -v cargo &> /dev/null; then
  cd "${PROJECT_DIR}/shazam-tui"
  cargo build --release --quiet 2>&1
  echo "        ✓ shazam-tui built ($(du -h target/release/shazam-tui | awk '{print $1}'))"
  cd "${PROJECT_DIR}"
else
  echo "        ⚠ cargo not found — skipping TUI build"
  echo "        Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
fi

# ── Step 2: Build Elixir escript ───────────────────────────
echo "  [2/3] Building Elixir escript (shazam)..."
cd "${PROJECT_DIR}"
mix escript.build 2>&1 | grep -v "^$" | head -3
echo "        ✓ shazam escript built"

# ── Step 3: Install to ~/bin ───────────────────────────────
echo "  [3/3] Installing to ${INSTALL_DIR}/..."
mkdir -p "${INSTALL_DIR}"

cp "${PROJECT_DIR}/shazam" "${INSTALL_DIR}/shazam"
chmod +x "${INSTALL_DIR}/shazam"

if [ -f "${PROJECT_DIR}/shazam-tui/target/release/shazam-tui" ]; then
  cp "${PROJECT_DIR}/shazam-tui/target/release/shazam-tui" "${INSTALL_DIR}/shazam-tui"
  chmod +x "${INSTALL_DIR}/shazam-tui"
  echo "        ✓ shazam-tui → ${INSTALL_DIR}/shazam-tui"
fi

echo "        ✓ shazam    → ${INSTALL_DIR}/shazam"
echo ""
echo "  ⚡ Done! Run 'shazam' to start."
