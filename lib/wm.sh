# shellcheck shell=bash
# `omacase wm <aerospace|yabai>` — choose the window-manager profile.
#
#   aerospace (default): no SIP disable, stable, i3-style tiling.
#   yabai (advanced):    real BSP dynamic tiling, but requires SIP partially
#                        disabled (manual Recovery step — see _yabai_notes).
# Both share SketchyBar + JankyBorders.

omacase_wm() {
  local profile="${1:-}"
  [ -n "$profile" ] || profile="$(gum_choose "Window manager profile" aerospace yabai)" || return

  case "$profile" in
    aerospace) _wm_use_aerospace ;;
    yabai)     _wm_use_yabai ;;
    *) abort "Unknown wm profile '$profile' (aerospace|yabai)" ;;
  esac
  is_dryrun || echo "$profile" > "$OMACASE_STATE/wm"
}

_wm_stop_all() {
  for svc in yabai skhd aerospace; do
    run brew services stop "$svc" 2>/dev/null || true
  done
  pgrep -x AeroSpace >/dev/null && run osascript -e 'quit app "AeroSpace"' 2>/dev/null || true
}

_wm_start_shared() {
  run brew services start borders 2>/dev/null || warn "borders not installed?"
  run brew services start sketchybar 2>/dev/null || warn "sketchybar not installed?"
}

_wm_use_aerospace() {
  info "Profile: AeroSpace (no SIP disable required)"
  _wm_stop_all
  # AeroSpace runs as a regular app from /Applications, started at login via
  # its own config (start-at-login = true). Just launch it now.
  run open -a AeroSpace 2>/dev/null || warn "AeroSpace not installed — check Brewfile/brew bundle."
  _wm_start_shared
  success "AeroSpace active. Alt+hjkl focus, Alt+Shift+hjkl move, Alt+[1-9] workspaces."
}

_wm_use_yabai() {
  info "Profile: yabai (advanced — needs SIP partially disabled)"
  if ! _sip_ok_for_yabai; then _yabai_notes; fi
  _wm_stop_all
  run brew services start yabai 2>/dev/null || warn "yabai not installed — add to Brewfile."
  run brew services start skhd  2>/dev/null || warn "skhd not installed — add to Brewfile."
  _wm_start_shared
  success "yabai active (if SIP/scripting-addition are configured)."
}

_sip_ok_for_yabai() {
  # Scripting addition needs SIP partially disabled; csrutil reports status.
  csrutil status 2>/dev/null | grep -qiE 'disabled|partial'
}

_yabai_notes() {
  warn "yabai's scripting addition needs SIP partially disabled."
  cat <<'EOF'
  This CANNOT be scripted from the running OS. Do it once:
    1. Apple menu → Restart, hold the power button to reach Recovery (Apple Silicon).
    2. Utilities → Terminal:  csrutil disable --with kext --with dtrace --with nvram
    3. Reboot, then:          sudo yabai --load-sa
    4. Re-run:                omacase wm yabai
  Prefer not to? Stay on AeroSpace — it needs none of this.
EOF
}
