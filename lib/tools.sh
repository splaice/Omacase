# shellcheck shell=bash
# `omacase tools` (alias: list-tools) — what Omacase installs, one line each.
# Rendered live from the Brewfile's section headers and per-entry comments, so
# the list can never drift from what install actually converges to. A test
# enforces that every Brewfile entry carries a comment.

omacase_tools() {
  local bold=$'\033[1;35m' reset=$'\033[0m'

  awk -v bold="$bold" -v reset="$reset" '
    /^# --- / {
      section = $0
      sub(/^# --- +/, "", section); sub(/ *-+$/, "", section)
      printed = 0
      next
    }
    /^(brew|cask) "/ {
      line = $0
      name = line; sub(/^(brew|cask) "/, "", name); sub(/".*$/, "", name)
      n = split(name, parts, "/"); name = parts[n]   # user/tap/name -> name
      desc = ""
      if (match(line, /# /)) { desc = substr(line, RSTART + 2) }
      if (!printed) { printf "\n%s%s%s\n", bold, section, reset; printed = 1 }
      printf "  %-22s %s\n", name, desc
    }
  ' "$OMACASE_ROOT/Brewfile"

  printf '\n%s%s%s\n' "$bold" "Pinned release assets" "$reset"
  printf '  %-22s %s\n' "ioskeley-mono" "IoskeleyMono Term Nerd Font — Ghostty's font; version+sha256 pinned in lib/fonts.sh → ~/Library/Fonts"

  printf '\n%s%s%s\n' "$bold" "Self-managed installers" "$reset"
  printf '  %-22s %s\n' "claude" "Claude Code — installs and updates itself"
  printf '  %-22s %s\n' "grok" "xAI Grok CLI — opt-in (OMACASE_INSTALL_GROK=1), self-updates"
}
