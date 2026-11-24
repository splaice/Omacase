# shellcheck shell=bash
# Application launch helpers: a new Ghostty window, the yazi popup, the default
# browser, and centered app overlays (music, Obsidian, 1Password, Messages,
# Todoist). macOS manages the windows; these only open, center, and hide them.

# `omacase terminal [command...]` — open a new window in the running Ghostty
# instance and optionally type a command into it.
omacase_terminal() {
  osascript - "$*" >/dev/null 2>&1 <<'APPLESCRIPT' || true
on run argv
  set theCmd to item 1 of argv
  if application "Ghostty" is running then
    tell application "Ghostty" to activate
    tell application "System Events" to tell process "Ghostty" to click menu item "New Window" of menu "File" of menu bar 1
  else
    tell application "Ghostty" to activate
  end if
  if theCmd is not "" then
    delay 0.5
    tell application "System Events"
      keystroke theCmd
      key code 36
    end tell
  end if
end run
APPLESCRIPT
}

# Center a Ghostty popup matched by title at roughly 65% of the main display.
_popup_center() {
  local match="$1" bounds sw sh w h px py
  bounds="$(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null | tr ',' ' ' || true)"
  # shellcheck disable=SC2086 # split the four numeric bounds into positional fields
  set -- $bounds
  sw="${3:-1440}"
  sh="${4:-900}"
  w=$((sw * 65 / 100))
  h=$((sh * 65 / 100))
  px=$(((sw - w) / 2))
  py=$(((sh - h) / 2))
  osascript - "$match" "$px" "$py" "$w" "$h" >/dev/null 2>&1 <<'OSA' || true
on run argv
  set m to item 1 of argv
  set px to (item 2 of argv) as integer
  set py to (item 3 of argv) as integer
  set ww to (item 4 of argv) as integer
  set hh to (item 5 of argv) as integer
  tell application "System Events" to tell process "Ghostty"
    set n to 0
    repeat until (exists (first window whose name contains m)) or n > 50
      delay 0.1
      set n to n + 1
    end repeat
    if exists (first window whose name contains m) then
      set win to (first window whose name contains m)
      set position of win to {px, py}
      set size of win to {ww, hh}
    end if
  end tell
end run
OSA
}

# Toggle a Ghostty TUI popup: open a new window, run the command, center it.
_ghostty_popup_toggle() {
  ensure_brew_env
  local match="$1" cmd="$2" proc="$3"
  if is_dryrun; then
    printf '\033[2m[dry-run]\033[0m toggle Ghostty popup %s → %s\n' "$match" "$cmd"
    return 0
  fi
  if pgrep -f "$proc" >/dev/null 2>&1; then
    pkill -f "$proc"
    return 0
  fi

  osascript -e 'tell application "Ghostty" to activate' \
    -e 'tell application "System Events" to tell process "Ghostty" to click menu item "New Window" of menu "File" of menu bar 1' \
    2>/dev/null
  sleep 0.4
  osascript - "$cmd" >/dev/null 2>&1 <<'OSA' || true
on run argv
  tell application "System Events"
    keystroke (item 1 of argv)
    key code 36
  end tell
end run
OSA
  sleep 0.2
  _popup_center "$match"
}

omacase_files() {
  # --cwd-file doubles as the unique argv marker _ghostty_popup_toggle pkills
  # (the role ranger's --confdir played before the yazi cutover).
  _ghostty_popup_toggle "omacase-files" \
    "printf '\033]0;omacase-files\007'; exec yazi --cwd-file='$HOME/.local/state/omacase/yazi-popup-cwd'" \
    "yazi --cwd-file=$HOME/.local/state/omacase/yazi-popup-cwd"
}

omacase_browser() {
  local id
  id="$(python3 - <<'PY' 2>/dev/null
import os
import plistlib

path = os.path.expanduser("~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist")
try:
    with open(path, "rb") as handle:
        data = plistlib.load(handle)
    for handler in data.get("LSHandlers", []):
        if handler.get("LSHandlerURLScheme") == "https":
            print(handler.get("LSHandlerRoleAll", ""))
            break
except Exception:
    pass
PY
)"
  if [ -n "$id" ]; then
    open -b "$id" 2>/dev/null || open -a Safari
  else
    open -a Safari
  fi
}

# Toggle a GUI app as a centered overlay: hide it when frontmost, otherwise
# launch/activate it and center its front window (optionally resized to pct%).
_app_toggle() {
  ensure_brew_env
  local app="$1" pct="${2:-0}" front
  if is_dryrun; then
    printf '\033[2m[dry-run]\033[0m toggle app %s\n' "$app"
    return 0
  fi
  front="$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null || true)"
  if [ "$front" = "$app" ]; then
    osascript -e "tell application \"System Events\" to set visible of process $(applescript_string "$app") to false" \
      2>/dev/null
    return 0
  fi

  open -a "$app" 2>/dev/null || {
    warn "Couldn't launch '$app' — is it installed?"
    return 1
  }
  osascript - "$app" "$pct" >/dev/null 2>&1 <<'OSA' || true
on run argv
  set a to item 1 of argv
  set pct to (item 2 of argv) as integer
  tell application "Finder" to set b to bounds of window of desktop
  set sw to (item 3 of b)
  set sh to (item 4 of b)
  tell application "System Events" to tell process a
    set n to 0
    repeat until (exists window 1) or n > 50
      delay 0.1
      set n to n + 1
    end repeat
    if exists window 1 then
      set win to window 1
      if pct > 0 then
        set {ww, hh} to {(sw * pct) div 100, (sh * pct) div 100}
        set size of win to {ww, hh}
      else
        set {ww, hh} to size of win
      end if
      set position of win to {(sw - ww) div 2, (sh - hh) div 2}
      perform action "AXRaise" of win
    end if
  end tell
end run
OSA
}

omacase_music() {
  local statef="$OMACASE_STATE/music-app" app
  case "${1:-}" in
    spotify)     is_dryrun || { ensure_state_dir; echo "Spotify" > "$statef"; } ;;
    apple|music) is_dryrun || { ensure_state_dir; echo "Music" > "$statef"; } ;;
    "")          : ;;
    *)           abort "usage: omacase music [spotify|apple]" ;;
  esac
  app="$(cat "$statef" 2>/dev/null || echo Spotify)"
  if ! osascript -e "id of app $(applescript_string "$app")" >/dev/null 2>&1; then
    if osascript -e 'id of app "Spotify"' >/dev/null 2>&1; then
      app="Spotify"
    elif osascript -e 'id of app "Music"' >/dev/null 2>&1; then
      app="Music"
    fi
  fi
  _app_toggle "$app"
}

omacase_obsidian() { _app_toggle "Obsidian"; }
omacase_1password() { _app_toggle "1Password"; }
omacase_todoist() { _app_toggle "Todoist"; }
omacase_message() { _app_toggle "Messages" 80; }
