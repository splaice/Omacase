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
ensure_supported_platform() {
  [ "$(uname -s)" = "Darwin" ] || abort "omacase only runs on macOS."
  [ "$(uname -m)" = "arm64" ] || abort "omacase supports Apple Silicon Macs only."
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

  if [ -L "$live" ] || [ ! -e "$live" ]; then
    mkdir -p "$(dirname "$live")"
    tmp="$(mktemp)"
    cat "$tracked" > "$tmp"
    rm -f "$live"
    mv "$tmp" "$live"
  fi

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
