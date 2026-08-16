# shellcheck shell=bash
# OmniWM lifecycle plus the small set of application launch helpers that remain
# useful outside the window manager. OmniWM owns layout, workspaces, hotkeys,
# borders, the workspace bar, rules, scratchpad, and quake terminal.

_omniwm_config_file() {
  printf '%s/.config/omniwm/settings.toml' "$HOME"
}

_wm_seed_config() {
  local live seed
  live="$(_omniwm_config_file)"
  seed="$OMACASE_ROOT/config/omniwm/settings.toml"
  [ -f "$seed" ] || abort "OmniWM seed missing: $seed"

  if [ -e "$live" ] || [ -L "$live" ]; then
    [ ! -L "$live" ] || warn "$live is a symlink; OmniWM may replace it when saving settings."
    info "Keeping existing OmniWM settings: $live"
    return 0
  fi

  run mkdir -p "$(dirname "$live")"
  run cp "$seed" "$live"
  is_dryrun || success "Seeded OmniWM settings → $live"
}

_wm_install_login_item() {
  # Login-time launches (OmniWM included, via ~/.config/omacase/login-items)
  # go through the OmacaseLauncher app bundle so Login Items shows a real name.
  source "$OMACASE_ROOT/lib/launcher.sh"
  _launcher_install
}

_wm_stop_all() {
  if pgrep -x OmniWM >/dev/null 2>&1; then
    run osascript -e 'tell application "OmniWM" to quit' >/dev/null 2>&1 || true
  fi
}

_wm_wait_for_omniwm() {
  is_dryrun && return 0
  local n=0
  until pgrep -x OmniWM >/dev/null 2>&1 || [ "$n" -ge 40 ]; do
    sleep 0.25
    n=$((n + 1))
  done
  pgrep -x OmniWM >/dev/null 2>&1
}

_wm_ipc_ready() {
  have omniwmctl || return 1
  omniwmctl ping >/dev/null 2>&1 &
  local pid=$! n=0
  while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 100 ]; do
    sleep 0.1
    n=$((n + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    return 1
  fi
  wait "$pid"
}

# `omacase wm menu|palette` — open OmniWM's app menu / command palette over
# IPC. macOS 26 can fail to register OmniWM's menu bar icon (it never appears
# under System Settings → Menu Bar), so these are the reliable entry points for
# keybinds.
_wm_open_ui() {
  ensure_brew_env
  local ipc="$1"
  if is_dryrun; then
    printf '\033[2m[dry-run]\033[0m omniwmctl command %s\n' "$ipc"
    return 0
  fi
  _wm_ipc_ready || abort "OmniWM IPC is not ready — run \`omacase wm\` first."
  omniwmctl command "$ipc" >/dev/null
}

# `omacase wm settings` — OmniWM has no IPC command or URL scheme for its
# settings window (checked 0.5.10), so activate the app and click the app
# menu's "Settings…" item via System Events.
_wm_open_settings() {
  if is_dryrun; then
    printf '\033[2m[dry-run]\033[0m open the OmniWM settings window\n'
    return 0
  fi
  pgrep -x OmniWM >/dev/null 2>&1 || abort "OmniWM is not running — run \`omacase wm\` first."
  osascript >/dev/null 2>&1 <<'OSA' ||
tell application "OmniWM" to activate
tell application "System Events" to tell process "OmniWM"
  click (first menu item of menu "OmniWM" of menu bar item "OmniWM" of menu bar 1 whose name begins with "Settings")
end tell
OSA
    warn "Couldn't open OmniWM settings — the calling app needs Accessibility and Automation consent."
}

omacase_wm() {
  case "${1:-}" in
    menu)     _wm_open_ui open-menu-anywhere; return ;;
    palette)  _wm_open_ui open-command-palette; return ;;
    settings) _wm_open_settings; return ;;
    "")       ;;
    *)        abort "usage: omacase wm [menu|palette|settings]" ;;
  esac

  ensure_brew_env
  _wm_seed_config
  _wm_install_login_item

  if [ ! -d /Applications/OmniWM.app ]; then
    warn "OmniWM is not installed — re-run \`omacase install\`."
    return 1
  fi

  if ! pgrep -x OmniWM >/dev/null 2>&1; then
    run open -a OmniWM
  fi
  if ! _wm_wait_for_omniwm; then
    warn "OmniWM did not launch. Grant Accessibility, then re-run \`omacase wm\`."
    return 1
  fi

  if _wm_ipc_ready; then
    local version
    version="$(omniwmctl version --format text 2>/dev/null | tr '\n' ' ' || true)"
    success "OmniWM active${version:+ — $version}"
  else
    warn "OmniWM is running, but IPC is not ready. Enable IPC from its menu if optional Omacase popup helpers need it."
  fi
  info "OmniWM owns shortcuts: Option+arrows focus, Option+Shift+arrows move, Option+[1-9] workspaces."
}

# `omacase terminal [command...]` — open a new window in the running Ghostty
# instance and optionally type a command into it. OmniWM admits the new window
# onto the active workspace; no workspace tracking or focus dance is needed.
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

# Toggle a Ghostty TUI popup. The newly created window starts tiled;
# float that one window directly without adding a persistent application rule.
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
  _wm_ipc_ready && omniwmctl command toggle-focused-window-floating >/dev/null 2>&1 || true
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

_wm_focused_mode_for_pid() {
  local pid="$1"
  omniwmctl query windows --focused --format json 2>/dev/null |
    python3 -c '
import json
import sys

pid = int(sys.argv[1])
for window in json.load(sys.stdin)["result"]["payload"]["windows"]:
    if window.get("pid") == pid and window.get("isFocused"):
        print(window.get("mode", ""))
        break
' "$pid" 2>/dev/null
}

_wm_ensure_focused_floating() {
  local pid="$1" mode="" n=0
  while [ "$n" -lt 50 ]; do
    mode="$(_wm_focused_mode_for_pid "$pid" || true)"
    case "$mode" in
      floating) return 0 ;;
      tiling)
        omniwmctl command toggle-focused-window-floating >/dev/null 2>&1
        return ;;
    esac
    sleep 0.1
    n=$((n + 1))
  done
  return 1
}

# Toggle a GUI app as a centered overlay. OmniWM's persisted app rules own the
# baseline constraints; the helper floats only a focused tiled window and leaves
# an existing floating window alone.
_app_toggle() {
  ensure_brew_env
  local app="$1" pct="${2:-0}" front pid
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
  sleep 0.3
  pid="$(osascript - "$app" <<'OSA' 2>/dev/null || true
on run argv
  tell application "System Events"
    if exists process (item 1 of argv) then return unix id of process (item 1 of argv)
  end tell
end run
OSA
)"
  if [ -n "$pid" ] && _wm_ipc_ready; then
    omniwmctl rule apply --pid "$pid" >/dev/null 2>&1 || true
    _wm_ensure_focused_floating "$pid" || \
      warn "Could not confirm a focused OmniWM window for '$app'; leaving its layout unchanged."
  fi

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
