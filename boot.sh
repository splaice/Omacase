#!/bin/bash
# omacase bootstrap — the curl|bash entry point.
#
#   /bin/bash -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://omacase.org/install)"
#
# site/install (served at omacase.org/install) is an exact copy of this file —
# edit HERE and run `cp boot.sh site/install`; tests/run.sh fails on drift.
#
# Installs the prerequisites (Xcode CLT, Homebrew), clones the payload to
# ~/.local/share/omacase/repo, and hands off to `omacase install`.
set -euo pipefail

REPO="${OMACASE_REPO:-https://github.com/splaice/omacase.git}"
PREFIX="${OMACASE_PREFIX:-$HOME/.local/share/omacase/repo}"

abort() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }
info()  { printf '\033[34m➜ %s\033[0m\n' "$*"; }

# Inlined from lib/common.sh: boot.sh cannot source the checkout (the destage
# is not in the tree yet). Keep this body in lockstep with _recover_legacy_login_items.
_recover_legacy_login_items() {
  local root="$1"
  local rel="home/dot_config/omacase/login-items"
  local tracked="$root/$rel"
  local live="$HOME/.config/omacase/login-items"
  local tmp
  [ -f "$tracked" ] || [ -L "$tracked" ] || return 0

  # Only replace the exact legacy link. A real file or unrelated symlink is
  # user-owned; do not clean checkout edits unless we first recover their bytes.
  if [ -L "$live" ]; then
    [ "$(readlink "$live")" = "$tracked" ] || return 0
  elif [ -e "$live" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$live")"
  tmp="$(mktemp)"
  cat "$tracked" > "$tmp"
  rm -f "$live"
  mv "$tmp" "$live"

  if [ -d "$root/.git" ]; then
    git -C "$root" checkout -- "$rel" 2>/dev/null || true
  fi
}

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
  # Homebrew/install publishes no tags; pin a reviewed commit + sha256.
  HOMEBREW_INSTALLER_VERSION=cced90146ea6d3057c03a636b668fef177415eb3
  HOMEBREW_INSTALLER_SHA256=12479a24be3f5307eecac7cde670fad7118640f031229e964f544b1367b52a41
  curl --proto '=https' --tlsv1.2 -fsSL \
    "https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALLER_VERSION}/install.sh" \
    -o "$installer"
  printf '%s  %s\n' "$HOMEBREW_INSTALLER_SHA256" "$installer" | shasum -a 256 -c -- >/dev/null 2>&1 \
    || abort "Homebrew installer checksum mismatch — refusing to run it. (Upstream may have released a new version; update omacase or install Homebrew manually from brew.sh, then re-run.)"
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
# stable (default) checks out the greatest v* tag; OMACASE_CHANNEL=dev tracks
# the default branch. A missing tag (pre-first-release) stays on the default
# branch rather than aborting bootstrap.
_omacase_remote_default_branch() {
  local root="$1" ref
  ref="$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  ref="${ref#origin/}"
  printf '%s\n' "${ref:-main}"
}

# stable leaves a detached tag checkout. Dev must attach to the remote
# default branch without reset --hard / checkout -B (those discard work).
_omacase_attach_dev() {
  local root="$1" branch
  branch="$(_omacase_remote_default_branch "$root")"
  git -C "$root" fetch origin "$branch"
  if git -C "$root" symbolic-ref -q HEAD >/dev/null; then
    git -C "$root" merge --ff-only "origin/$branch"
    return
  fi
  info "Attaching detached checkout to origin/$branch (dev channel)…"
  if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$root" checkout -q "$branch" \
      || abort "Could not check out $branch (local changes?). Resolve them or stay on OMACASE_CHANNEL=stable."
  else
    git -C "$root" checkout -q --track "origin/$branch" \
      || abort "Could not attach to origin/$branch (local changes?). Resolve them or stay on OMACASE_CHANNEL=stable."
  fi
  git -C "$root" merge --ff-only "origin/$branch" \
    || abort "git merge --ff-only origin/$branch failed (local changes?). Resolve it before updating."
}

_omacase_checkout_channel() {
  local root="$1" tag
  if [ "${OMACASE_CHANNEL:-stable}" = dev ]; then
    _omacase_attach_dev "$root"
    return
  fi
  git -C "$root" fetch --tags --depth 1 origin 2>/dev/null || true
  tag="$(git -C "$root" tag --list 'v*' --sort=-v:refname | head -1)"
  if [ -n "$tag" ]; then
    git -C "$root" checkout -q "$tag"
  else
    info "No release tags found; staying on the default branch (set OMACASE_CHANNEL=dev to keep tracking it)."
  fi
}
# Older public installs cloned into the data root itself. Keep using that
# checkout rather than forking a second copy next to its caches.
if [ -z "${OMACASE_PREFIX:-}" ] && [ -d "$HOME/.local/share/omacase/.git" ]; then
  PREFIX="$HOME/.local/share/omacase"
  info "Using existing checkout at $PREFIX (pre-repo/ layout)."
fi
if [ -d "$PREFIX/.git" ]; then
  info "Updating existing omacase payload at $PREFIX…"
  _recover_legacy_login_items "$PREFIX"
  _omacase_checkout_channel "$PREFIX"
else
  info "Cloning omacase → $PREFIX…"
  mkdir -p "$(dirname "$PREFIX")"
  git clone --tags --depth 1 "$REPO" "$PREFIX"
  _omacase_checkout_channel "$PREFIX"
fi

# 4. Hand off.
info "Running omacase install…"
exec "$PREFIX/bin/omacase" install
