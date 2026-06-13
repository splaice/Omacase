# shellcheck shell=bash
# `omacase notify [--title T] [--subtitle S] [--sound NAME] <message…>`
#
# A native macOS notification primitive for omacase commands, keybinds, and your
# own scripts. Keybind-driven actions run with no terminal to print to, so this
# is how they surface "done / nothing to do / failed" (see `omacase grid`).
#
# Two backends, in order of preference:
#   1. terminal-notifier (Brewfile) — registers its own bundle in Notifications,
#      so banners reliably show and can be allowed once in System Settings.
#   2. osascript `display notification` — no dependency, but attributed to Script
#      Editor and FLAKY on modern macOS (banners are intermittent). Fallback only.
# Either backend is suppressed while a Focus / Do-Not-Disturb is on, and needs
# Notification permission for its owning app — that's macOS, not us. Best-effort:
# never fails the caller (a missing banner shouldn't break a script).
omacase_notify() {
  ensure_brew_env   # may run from a keybind whose PATH lacks Homebrew (→ terminal-notifier)
  local title="Omacase" subtitle="" sound=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -t|--title)    title="${2:-}";    shift 2 ;;
      --subtitle)    subtitle="${2:-}"; shift 2 ;;
      -s|--sound)    sound="${2:-}";    shift 2 ;;  # e.g. Glass, Ping, Hero (see /System/Library/Sounds)
      --)            shift; break ;;
      -*)            abort "notify: unknown option '$1' (use --title/--subtitle/--sound)" ;;
      *)             break ;;
    esac
  done

  local msg="$*"
  [ -n "$msg" ] || abort "usage: omacase notify [--title T] [--subtitle S] [--sound NAME] <message>"

  # Preferred backend. terminal-notifier takes its strings as argv (no shell
  # eval), so they're injection-safe; only pass subtitle/sound when set.
  if have terminal-notifier; then
    local args=(-title "$title" -message "$msg")
    [ -n "$subtitle" ] && args+=(-subtitle "$subtitle")
    [ -n "$sound" ]    && args+=(-sound "$sound")
    terminal-notifier "${args[@]}" >/dev/null 2>&1 || true
    return 0
  fi

  # Fallback. Pass every string as argv so quotes/backslashes in the message
  # can't break out of the AppleScript (the pattern the wm.sh osascript helpers
  # use). Only attach subtitle/sound when set, so an empty value isn't rendered.
  osascript - "$msg" "$title" "$subtitle" "$sound" >/dev/null 2>&1 <<'OSA' || true
on run argv
  set msg to item 1 of argv
  set t to item 2 of argv
  set st to item 3 of argv
  set snd to item 4 of argv
  if st is "" and snd is "" then
    display notification msg with title t
  else if snd is "" then
    display notification msg with title t subtitle st
  else if st is "" then
    display notification msg with title t sound name snd
  else
    display notification msg with title t subtitle st sound name snd
  end if
end run
OSA
}
