# shellcheck shell=bash
# Shared helpers: logging, idempotency guards, brew/PATH bootstrap, state dir.
# Sourced by bin/macarchy and every lib/*.sh.

MACARCHY_STATE="${MACARCHY_STATE:-$HOME/.local/state/macarchy}"
mkdir -p "$MACARCHY_STATE"

# --- logging -----------------------------------------------------------------
_c()      { printf '\033[%sm' "$1"; }
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
ensure_brew_env() {
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"
  else abort "Homebrew not found — run boot.sh first."; fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# --- idempotency -------------------------------------------------------------
# once <key> <command...> : run command only the first time, record a marker.
# Use for genuinely one-shot actions (e.g. changing login shell). Most steps
# should instead be naturally idempotent (brew bundle, chezmoi apply).
once() {
  local key="$1"; shift
  local marker="$MACARCHY_STATE/once.$key"
  if [ -f "$marker" ]; then return 0; fi
  "$@" && touch "$marker"
}

# --- gum (optional TUI sugar) ------------------------------------------------
gum_choose() { # gum_choose "header" opt1 opt2 ...  -> prints choice
  local header="$1"; shift
  if have gum; then gum choose --header "$header" "$@"
  else
    printf '%s\n' "$header" >&2
    select c in "$@"; do [ -n "$c" ] && { printf '%s\n' "$c"; return; }; done
  fi
}
