# shellcheck shell=bash
# Small, scriptable actions — the macOS analog of Omarchy's launcher/menu
# helpers (the toggle scripts). Each is a clean one-liner,
# reachable from `omacase menu` or callable directly, so it also drops into a
# macOS Shortcut's "Run Shell Script" step if you want to bind one yourself.

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
