# shellcheck shell=bash
# Shared helpers: logging, idempotency guards, brew/PATH bootstrap, state dir.
# Sourced by bin/omacase and every lib/*.sh.

OMACASE_STATE="${OMACASE_STATE:-$HOME/.local/state/omacase}"
# Data/cache dir for downloaded artifacts (e.g. per-theme wallpapers).
OMACASE_DATA="${OMACASE_DATA:-$HOME/.local/share/omacase}"

# --- logging -----------------------------------------------------------------
log()     { printf '%s\n' "$*"; }
info()    { printf '\033[34m➜\033[0m %s\n' "$*"; }
success() { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn()    { printf '\033[33m! \033[0m%s\n' "$*" >&2; }
error()   { printf '\033[31m✗\033[0m %s\n' "$*" >&2; }
step()    { printf '\n\033[1;35m▒▒ %s\033[0m\n' "$*"; }

abort()   { error "$*"; exit 1; }

confirm() { # confirm "Question?" -> 0 if yes
  local reply
  read -r -p "$(printf '\033[36m? %s [y/N] \033[0m' "$1")" reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# --- environment -------------------------------------------------------------
OMACASE_MACOS_MIN=26

# Pure comparison so tests can feed arbitrary strings. Accepts "26", "26.0",
# "26.6.1"; compares the MAJOR only (Omacase supports a major, not a minor).
_macos_version_supported() {
  local major="${1%%.*}"
  case "$major" in ''|*[!0-9]*) return 1 ;; esac
  [ "$major" -ge "$OMACASE_MACOS_MIN" ]
}

ensure_supported_platform() {
  [ "$(uname -s)" = "Darwin" ] || abort "omacase only runs on macOS."
  [ "$(uname -m)" = "arm64" ] || abort "omacase supports Apple Silicon Macs only."
  local v; v="$(sw_vers -productVersion 2>/dev/null)"
  _macos_version_supported "$v" || \
    abort "omacase requires macOS $OMACASE_MACOS_MIN or later (detected: ${v:-unknown})."
}

ensure_brew_env() {
  ensure_supported_platform
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif is_dryrun; then
    warn "Homebrew not found at /opt/homebrew (dry run — continuing)."
    export HOMEBREW_PREFIX=/opt/homebrew
    export PATH="/opt/homebrew/bin:$PATH"
  else
    abort "Homebrew not found at /opt/homebrew — run boot.sh first."
  fi
}

# Best-effort branded desktop notification for keybind-driven commands (which
# have no terminal to print to). Thin wrapper over lib/notify.sh with the
# Omacase title + icon preset; pass extra omacase_notify options to override
# (later options win, so `notify --title X msg` re-titles the banner).
notify() {
  source "$OMACASE_ROOT/lib/notify.sh"
  omacase_notify --title "Omacase" --image "$OMACASE_ROOT/assets/omacase-icon.png" "$@"
}

# Like ensure_brew_env, but for commands that have a brew-free fallback:
# wire up Homebrew when present, carry on without it otherwise.
brew_env_if_available() {
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# The directory the `omacase` command is symlinked into so it lands on PATH.
# Omacase supports Apple Silicon Homebrew only: /opt/homebrew.
_omacase_bindir() {
  if [ -d /opt/homebrew/bin ] || is_dryrun; then
    printf '%s\n' /opt/homebrew/bin
  fi
}

# Homebrew's zsh completion dir (sibling of bin). Anything linked here is
# completable in every shell: `brew shellenv` puts it on fpath, and the managed
# ~/.zshrc runs compinit.
_omacase_zfuncdir() {
  local bindir; bindir="$(_omacase_bindir)"
  [ -n "$bindir" ] && printf '%s\n' "${bindir%/bin}/share/zsh/site-functions"
}

# Copy login-items out of a legacy checkout and restore the tracked file so a
# pull that destages home/dot_config/omacase/login-items can fast-forward.
# Edits made through the old symlink dirty that tracked path; without this,
# git pull --ff-only refuses the destage.
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

  if is_dryrun; then
    log "[dry-run] would recover legacy login-items before updating the checkout"
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

# True if PATH is a symlink that already points inside this repo or Omacase's
# generated theme cache.
_is_omacase_link() {
  local t="$1" dest
  [ -L "$t" ] || return 1
  dest="$(readlink "$t")"
  case "$dest" in
    "$OMACASE_ROOT"/*|"$OMACASE_DATA"/generated/themes/*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- sudo priming -------------------------------------------------------------
# Omacase itself never escalates. Homebrew does — as a string of separate `sudo`
# calls while installing/upgrading casks (pkg installers, launchctl/pkgutil
# uninstall stanzas, app bundles it cannot write). Under macOS's stock policy
# (5-minute, per-tty timestamp) a long brew run re-prompts between them.
# sudo_prime asks once up front and refreshes the timestamp in the background
# until this process exits, so every later `sudo` hits the cache. Only casks
# ever need it: a formulae-only run never asks. (`omacase extras sudo-touchid`
# turns the one prompt into a Touch ID shared across terminals for an hour.)
_SUDO_PRIMED=""
_SUDO_KEEPALIVE_PID=""

# Cask tokens this run may install or upgrade: outdated installed casks plus
# Brewfile casks not installed yet. Empty = nothing cask-side moves. Read-only;
# honors whatever HOMEBREW_* upgrade policy the caller has exported so the
# answer matches what `brew bundle`/`brew upgrade` will actually touch.
_pending_casks() {
  local declared installed t
  HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --cask --quiet 2>/dev/null || true
  installed="$(brew list --cask -1 2>/dev/null || true)"
  declared="$(sed -nE 's/^cask[[:space:]]+"([^"]+)".*/\1/p' "$OMACASE_ROOT/Brewfile")"
  for t in $declared; do
    grep -qx "${t##*/}" <<< "$installed" || printf '%s\n' "$t"
  done
}

_sudo_keepalive_stop() {
  [ -n "$_SUDO_KEEPALIVE_PID" ] && kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null
  _SUDO_KEEPALIVE_PID=""
  return 0
}

# sudo_prime — idempotent per process (update nests install; prime once).
sudo_prime() {
  [ -n "$_SUDO_PRIMED" ] && return 0
  _SUDO_PRIMED=1
  # No way to ask: not a terminal and no askpass helper. Leave it to brew.
  { [ -t 0 ] || [ -n "${SUDO_ASKPASS:-}" ]; } || return 0
  local pending
  pending="$(_pending_casks | tr '\n' ' ')"
  pending="${pending% }"
  [ -n "$pending" ] || return 0
  if is_dryrun; then
    log "[dry-run] would authenticate once for Homebrew casks that may need admin rights: $pending"
    return 0
  fi
  # Already cached (e.g. the sudo-touchid extra's shared hour): refresh silently.
  if ! sudo -n -v 2>/dev/null; then
    step "Homebrew may need admin rights for: $pending"
    info "Authenticating once for this run (\`omacase extras sudo-touchid\` makes it a Touch ID, shared across terminals for an hour)."
    if ! sudo -v; then
      warn "sudo authentication failed — Homebrew will ask itself for casks that need it."
      return 0
    fi
  fi
  # Refresh the stock 5-minute, per-tty timestamp until this process exits.
  # `$$` is the main shell even inside the subshell; `sudo -n` never prompts.
  ( while kill -0 "$$" 2>/dev/null; do sudo -n -v 2>/dev/null || exit 0; sleep 50; done ) >/dev/null 2>&1 &
  _SUDO_KEEPALIVE_PID=$!
  trap _sudo_keepalive_stop EXIT
}

# --- convergence ledger -------------------------------------------------------
# Required steps that fail are recorded (not fatal) so independent work
# continues; the entry point reports partial convergence and exits nonzero.
OMACASE_INCOMPLETE=()

# require <label> <cmd...> — run a REQUIRED convergence step; on failure, warn
# and record. Optional steps keep using plain `run … || warn` and never ledger.
require() {
  local label="$1"; shift
  if ! run "$@"; then
    warn "$label failed — continuing with remaining steps."
    OMACASE_INCOMPLETE+=("$label")
    return 0
  fi
}

converged() {  # converged "<verb phrase>" — final report + exit status
  if [ "${#OMACASE_INCOMPLETE[@]}" -eq 0 ]; then
    success "$1"
    return 0
  fi
  warn "PARTIAL: $1 — ${#OMACASE_INCOMPLETE[@]} required step(s) failed:"
  local s
  for s in "${OMACASE_INCOMPLETE[@]}"; do
    warn "  - $s"
  done
  warn "Re-run \`omacase update\` after fixing the above."
  return 1
}


# --- dry run -----------------------------------------------------------------
# Set OMACASE_DRYRUN=1 to print mutating commands instead of running them.
# Wrap every side-effecting command (brew, ln, defaults, services…)
# in `run`. Read-only inspection commands don't need it.
is_dryrun() { [ -n "${OMACASE_DRYRUN:-}" ]; }

run() {
  if is_dryrun; then
    printf '\033[2m[dry-run]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

ensure_state_dir() {
  run mkdir -p "$OMACASE_STATE"
  run chmod 700 "$OMACASE_STATE"
}

shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

applescript_string() {
  printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

dryrun_banner() {
  # NOTE: must return 0 — called as a bare statement under `set -e`.
  if is_dryrun; then printf '\033[1;33m▒▒ DRY RUN — no changes will be made ▒▒\033[0m\n'; fi
}

# --- macOS appearance automation ---------------------------------------------
# Switching themes flips macOS Light/Dark via AppleScript to System Events,
# which requires Automation consent for the controlling terminal. This probe is
# read-only (it *gets* dark mode), but it exercises the exact same TCC grant, so
# it both tests and — on first run — triggers the consent prompt. Returns 0 when
# appearance control is allowed, 1 when blocked or unavailable.
can_set_appearance() {
  case "$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>&1)" in
    true|false) return 0 ;;
    *)          return 1 ;;
  esac
}

# --- gum (optional TUI sugar) ------------------------------------------------
gum_choose() { # gum_choose "header" opt1 opt2 ...  -> prints choice
  local header="$1"; shift
  if have gum; then
    # gum's default --height=10 truncates longer menus; show every option,
    # clamped to the terminal (1 row goes to the header).
    local height=$# rows
    rows="$(tput lines 2>/dev/null || echo 0)"
    [ "$rows" -gt 1 ] && [ "$height" -gt $((rows - 1)) ] && height=$((rows - 1))
    gum choose --height "$height" --header "$header" "$@"
  else
    printf '%s\n' "$header" >&2
    select c in "$@"; do [ -n "$c" ] && { printf '%s\n' "$c"; return; }; done
  fi
}
