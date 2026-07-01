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
  brew_env_if_available   # keybind PATH lacks Homebrew (→ terminal-notifier); the osascript fallback needs no brew
  local title="Omacase" subtitle="" sound="" image=""
  # An option with a missing value would make `shift 2` fail — a silent set -e
  # death instead of the usage error below, so check before consuming.
  _notify_optval() { [ "$1" -ge 2 ] || abort "notify: '$2' needs a value"; }
  while [ $# -gt 0 ]; do
    case "$1" in
      -t|--title)    _notify_optval $# "$1"; title="$2";    shift 2 ;;
      --subtitle)    _notify_optval $# "$1"; subtitle="$2"; shift 2 ;;
      -s|--sound)    _notify_optval $# "$1"; sound="$2";    shift 2 ;;  # e.g. Glass, Ping, Hero (see /System/Library/Sounds)
      -i|--image)    _notify_optval $# "$1"; image="$2";    shift 2 ;;  # path to an image shown on the banner's right (terminal-notifier only)
      --)            shift; break ;;
      -*)            abort "notify: unknown option '$1' (use --title/--subtitle/--sound/--image)" ;;
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
    # -contentImage shows on the banner's right. macOS pins the LEFT app icon to
    # the sender (terminal-notifier), so this is the reliable way to brand a banner.
    [ -n "$image" ] && [ -f "$image" ] && args+=(-contentImage "$image")
    terminal-notifier "${args[@]}" >/dev/null 2>&1 || true
    return 0
  fi
  # (osascript fallback can't render images, so --image is silently dropped there.)

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
