# shellcheck shell=bash
# Small, scriptable actions meant to be wrapped in a macOS Shortcut and triggered
# from Spotlight — the macOS analog of Omarchy's Super-key launcher/menu helpers
# (omarchy-launch-webapp, the toggle scripts). Each is a clean one-liner a
# Shortcut's "Run Shell Script" step can call.

# Omarchy's default web-app set (name -> URL). Kept in sync with Omarchy's
# config/hypr/bindings.conf Super+Shift web apps.
_webapp_url() {
  case "$1" in
    chatgpt)  echo "https://chatgpt.com" ;;
    grok)     echo "https://grok.com" ;;
    calendar) echo "https://app.hey.com/calendar/weeks/" ;;
    email)    echo "https://app.hey.com" ;;
    youtube)  echo "https://youtube.com/" ;;
    whatsapp) echo "https://web.whatsapp.com/" ;;
    messages) echo "https://messages.google.com/web/conversations" ;;
    photos)   echo "https://photos.google.com/" ;;
    x)        echo "https://x.com/" ;;
    x-post)   echo "https://x.com/compose/post" ;;
    *)        return 1 ;;
  esac
}
_webapp_names="chatgpt grok calendar email youtube whatsapp messages photos x x-post"

# omacase webapp [name] — open a named web app. With no name (or `list`), print
# the set. Opens as a chromeless "app" window when a Chromium browser is present
# (Omarchy's PWA feel), otherwise in the default browser.
omacase_webapp() {
  local name="${1:-}"
  if [ -z "$name" ] || [ "$name" = list ]; then
    info "Web apps — \`omacase webapp <name>\`:"
    local n; for n in $_webapp_names; do printf '  %-9s %s\n' "$n" "$(_webapp_url "$n")"; done
    return 0
  fi
  local url; url="$(_webapp_url "$name")" || abort "Unknown web app '$name'. Try: $_webapp_names"
  local b
  for b in "Google Chrome" "Brave Browser" "Microsoft Edge" "Vivaldi" "Chromium"; do
    if [ -d "/Applications/$b.app" ]; then
      run open -na "$b" --args "--app=$url"; return 0
    fi
  done
  run open "$url"   # default browser fallback
}

# omacase appearance [toggle|dark|light] — flip or set macOS system Light/Dark.
# The analog of Omarchy's nightlight toggle. This changes only the system
# appearance; use `omacase theme` to switch the whole palette (which also flips
# appearance to match).
omacase_appearance() {
  local want="${1:-toggle}" cur dark
  cur="$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>/dev/null || true)"
  case "$want" in
    toggle) [ "$cur" = true ] && dark=false || dark=true ;;
    dark)   dark=true ;;
    light)  dark=false ;;
    *) abort "usage: omacase appearance [toggle|dark|light]" ;;
  esac
  if run osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark"; then
    info "macOS appearance → $([ "$dark" = true ] && echo Dark || echo Light)"
  else
    warn "Couldn't set appearance — grant Automation → System Events to the caller (\`omacase doctor\`)."
  fi
}
