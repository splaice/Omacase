#!/bin/bash
# omacase bootstrap — the curl|bash entry point.
#
#   /bin/bash -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://omacase.org/install)"
#
# site/install (served at omacase.org/install) is an exact copy of this file —
# edit HERE and run `cp boot.sh site/install`; tests/run.sh fails on drift.
#
# Installs the prerequisites (Xcode CLT, Homebrew), clones the payload to
# ~/.local/share/omacase, and hands off to `omacase install`.
set -euo pipefail

REPO="${OMACASE_REPO:-https://github.com/splaice/omacase.git}"
PREFIX="${OMACASE_PREFIX:-$HOME/.local/share/omacase}"

abort() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }
info()  { printf '\033[34m➜ %s\033[0m\n' "$*"; }

[ "$(uname -s)" = "Darwin" ] || abort "omacase only runs on macOS."
[ "$(uname -m)" = "arm64" ] || abort "omacase supports Apple Silicon Macs only."
MACOS_MIN=26
v="$(sw_vers -productVersion 2>/dev/null)"; major="${v%%.*}"
case "$major" in ''|*[!0-9]*) major=0 ;; esac
[ "$major" -ge "$MACOS_MIN" ] || abort "omacase requires macOS $MACOS_MIN or later (detected: ${v:-unknown})."

# 1. Xcode Command Line Tools (provides git + compilers Homebrew needs).
if ! xcode-select -p >/dev/null 2>&1; then
  info "Installing Xcode Command Line Tools — accept the GUI prompt, then re-run this."
  xcode-select --install || true
  abort "Re-run boot.sh once the Command Line Tools finish installing."
fi

# 2. Homebrew.
if ! command -v brew >/dev/null 2>&1; then
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  info "Installing Homebrew…"
  curl --proto '=https' --tlsv1.2 -fsSL \
    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
    -o "$installer"
  NONINTERACTIVE=1 /bin/bash "$installer"
  rm -f "$installer"
  trap - EXIT
fi
# Put Apple Silicon Homebrew on PATH for this process.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  abort "Homebrew was not installed at /opt/homebrew; re-run boot.sh after Homebrew finishes."
fi

# 3. Clone or update the payload.
if [ -d "$PREFIX/.git" ]; then
  info "Updating existing omacase payload at $PREFIX…"
  git -C "$PREFIX" pull --ff-only
else
  info "Cloning omacase → $PREFIX…"
  mkdir -p "$(dirname "$PREFIX")"
  git clone --depth 1 "$REPO" "$PREFIX"
fi

# 4. Hand off.
info "Running omacase install…"
exec "$PREFIX/bin/omacase" install
