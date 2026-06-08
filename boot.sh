#!/bin/bash
# omacase bootstrap — the curl|bash entry point.
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/splaice/omacase/main/boot.sh)"
#
# Installs the prerequisites (Xcode CLT, Homebrew), clones the payload to
# ~/.local/share/omacase, and hands off to `omacase install`.
set -euo pipefail

REPO="${OMACASE_REPO:-https://github.com/splaice/omacase.git}"
PREFIX="${OMACASE_PREFIX:-$HOME/.local/share/omacase}"

abort() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }
info()  { printf '\033[34m➜ %s\033[0m\n' "$*"; }

[ "$(uname -s)" = "Darwin" ] || abort "omacase only runs on macOS."

# 1. Xcode Command Line Tools (provides git + compilers Homebrew needs).
if ! xcode-select -p >/dev/null 2>&1; then
  info "Installing Xcode Command Line Tools — accept the GUI prompt, then re-run this."
  xcode-select --install || true
  abort "Re-run boot.sh once the Command Line Tools finish installing."
fi

# 2. Homebrew.
if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew…"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# Put brew on PATH for this process (Apple Silicon vs Intel).
if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi

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
