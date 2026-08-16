# shellcheck shell=bash
# `omacase extras` — optional, opt-in tweaks for after install. Nothing here
# runs during `omacase install`; each extra is enabled explicitly, shows its
# state with `status`, and reverts with `off`.

_EXTRAS_SUDOERS_FILE=/etc/sudoers.d/omacase
_EXTRAS_PAM_SUDO_LOCAL=/etc/pam.d/sudo_local
_EXTRAS_PAM_TEMPLATE=/etc/pam.d/sudo_local.template
_EXTRAS_SUDO_TIMEOUT_MIN=60

omacase_extras() {
  local name="${1:-}"; shift || true
  case "$name" in
    "")           _extras_pick ;;
    list)         _extras_list ;;
    sudo-touchid)  _extra_sudo_touchid "${1:-on}" ;;
    mole)          _extra_mole "$@" ;;
    usage-tracker) _extra_usage_tracker "${1:-on}" ;;
    *) error "unknown extra: $name"; echo; _extras_list; return 1 ;;
  esac
}

_extras_list() {
  log "Optional post-install tweaks — omacase extras <name> [args]:"
  printf '  %-13s (%s)  Touch ID for sudo + %s-min credential cache shared across terminals [on|off|status]\n' \
    "sudo-touchid" "$(_extra_sudo_touchid_state)" "$_EXTRAS_SUDO_TIMEOUT_MIN"
  printf '  %-13s (run)  mole system toolbox: clean, uninstall, optimize, analyze (`mo`)\n' "mole"
  printf '  %-13s (%s)  background refresh for `omacase usage` every 15 min [on|off|status]\n' \
    "usage-tracker" "$(_extra_usage_tracker_state)"
}

_extras_pick() {
  local choice action
  choice="$(gum_choose "Extras — optional tweaks, enable only what you want" \
    "sudo-touchid — Touch ID for sudo + a longer, shared credential cache" \
    "mole — deep clean, app uninstall, optimize, disk analysis (mo)" \
    "usage-tracker — keep the agent usage dashboard fresh in the background" \
    "Back")" || return
  case "$choice" in
    sudo-touchid*)
      action="$(gum_choose "sudo-touchid" "Status" "Enable" "Disable" "Back")" || return
      case "$action" in
        Status)  _extra_sudo_touchid status ;;
        Enable)  _extra_sudo_touchid on ;;
        Disable) _extra_sudo_touchid off ;;
        *)       return ;;
      esac ;;
    mole*)
      _extra_mole ;;
    usage-tracker*)
      action="$(gum_choose "usage-tracker" "Status" "Enable" "Disable" "Back")" || return
      case "$action" in
        Status)  _extra_usage_tracker status ;;
        Enable)  _extra_usage_tracker on ;;
        Disable) _extra_usage_tracker off ;;
        *)       return ;;
      esac ;;
    *) return ;;
  esac
}

# --- usage-tracker -----------------------------------------------------------
# LaunchAgent that runs `omacase usage update` every 15 minutes so the
# dashboard (and anything reading its JSON records) is always fresh. Opt-in:
# it is a background process polling agent transcripts and, for Claude, an
# authenticated usage endpoint.

_EXTRAS_USAGE_AGENT="$HOME/Library/LaunchAgents/org.omacase.usage.plist"
_EXTRAS_USAGE_LABEL="org.omacase.usage"

_extra_usage_tracker_state() {
  [ -f "$_EXTRAS_USAGE_AGENT" ] && echo on || echo off
}

_extra_usage_tracker() {
  local domain
  domain="gui/$(id -u)"
  case "${1:-on}" in
    on)
      step "Enabling usage-tracker (refreshes \`omacase usage\` every 15 min)"
      local stage
      stage="$(mktemp -d)"
      cat > "$stage/agent.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$_EXTRAS_USAGE_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$OMACASE_ROOT/bin/omacase</string>
    <string>usage</string>
    <string>update</string>
  </array>
  <key>StartInterval</key>
  <integer>900</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardErrorPath</key>
  <string>$HOME/.local/state/omacase/usage/tracker.log</string>
</dict>
</plist>
EOF
      run mkdir -p "$(dirname "$_EXTRAS_USAGE_AGENT")" "$HOME/.local/state/omacase/usage"
      run cp "$stage/agent.plist" "$_EXTRAS_USAGE_AGENT"
      rm -rf "$stage"
      if ! is_dryrun; then
        launchctl bootout "$domain/$_EXTRAS_USAGE_LABEL" >/dev/null 2>&1 || true
        launchctl bootstrap "$domain" "$_EXTRAS_USAGE_AGENT" >/dev/null 2>&1 || \
          warn "Could not register the usage tracker with launchd."
      fi
      success "usage-tracker on — \`omacase usage\` stays fresh"
      ;;
    off)
      step "Disabling usage-tracker"
      run launchctl bootout "$domain/$_EXTRAS_USAGE_LABEL" 2>/dev/null || true
      run rm -f "$_EXTRAS_USAGE_AGENT"
      success "usage-tracker off (state records kept; \`omacase usage\` refreshes on demand)"
      ;;
    status)
      step "Extra: usage-tracker ($(_extra_usage_tracker_state))"
      if [ -f "$_EXTRAS_USAGE_AGENT" ]; then
        success "LaunchAgent installed ($_EXTRAS_USAGE_AGENT)"
      else
        warn "not enabled — \`omacase usage\` still works, refreshing on demand"
      fi
      local newest
      newest="$(find "$HOME/.local/state/omacase/usage" -name '*.json' -mmin -30 2>/dev/null | wc -l | tr -d ' ')"
      [ "$newest" -gt 0 ] && success "state records fresh (<30 min)" || warn "state records stale or absent"
      ;;
    *) error "usage: omacase extras usage-tracker [on|off|status]"; return 1 ;;
  esac
}

# --- mole --------------------------------------------------------------------
# Thin pass-through to mole (a default Brewfile package): with no args `mo`
# opens its own interactive menu (clean, uninstall, optimize, analyze…); args
# route to subcommands, e.g. `omacase extras mole clean --dry-run`. Kept under
# extras because it is an on-demand toolbox, not part of install/update.

_extra_mole() {
  have mo || abort "mole is not installed — run \`omacase install\` (or \`brew install mole\`)."
  mo "$@"
}

# --- sudo-touchid ------------------------------------------------------------
# Two independent pieces, reported separately by `status`:
#  1. /etc/pam.d/sudo_local with pam_tid.so active — sudo accepts Touch ID
#     (Apple's supported hook; survives OS updates, unlike editing pam.d/sudo).
#  2. /etc/sudoers.d/omacase — credential cache raised to
#     $_EXTRAS_SUDO_TIMEOUT_MIN minutes and shared across terminals
#     (timestamp_type=global) instead of per-tty.

_extra_sudo_touchid_pam_active() {
  [ -f "$_EXTRAS_PAM_SUDO_LOCAL" ] &&
    grep -Eq '^auth[[:space:]].*pam_tid\.so' "$_EXTRAS_PAM_SUDO_LOCAL"
}

_extra_sudo_touchid_state() {
  local pam=off cache=off
  _extra_sudo_touchid_pam_active && pam=on
  [ -f "$_EXTRAS_SUDOERS_FILE" ] && cache=on
  if [ "$pam" = on ] && [ "$cache" = on ]; then echo on
  elif [ "$pam" = off ] && [ "$cache" = off ]; then echo off
  else echo partial; fi
}

_extra_sudo_touchid() {
  case "${1:-on}" in
    on)     _extra_sudo_touchid_on ;;
    off)    _extra_sudo_touchid_off ;;
    status) _extra_sudo_touchid_status ;;
    *) error "usage: omacase extras sudo-touchid [on|off|status]"; return 1 ;;
  esac
}

_extra_sudo_touchid_status() {
  step "Extra: sudo-touchid ($(_extra_sudo_touchid_state))"
  if _extra_sudo_touchid_pam_active; then
    success "Touch ID for sudo is active ($_EXTRAS_PAM_SUDO_LOCAL)"
  else
    warn "Touch ID for sudo is not active"
  fi
  if [ -f "$_EXTRAS_SUDOERS_FILE" ]; then
    success "sudo credential cache tuned ($_EXTRAS_SUDOERS_FILE)"
  else
    warn "sudo credential cache at macOS defaults (5 min, per-terminal)"
  fi
}

_extra_sudo_touchid_on() {
  step "Enabling sudo-touchid (may prompt for your password — one last time)"

  # 1. Touch ID via the sudo_local hook.
  if _extra_sudo_touchid_pam_active; then
    success "Touch ID for sudo already active"
  elif [ ! -f "$_EXTRAS_PAM_SUDO_LOCAL" ]; then
    [ -f "$_EXTRAS_PAM_TEMPLATE" ] || abort "missing $_EXTRAS_PAM_TEMPLATE (macOS 14+ required)"
    run sudo cp "$_EXTRAS_PAM_TEMPLATE" "$_EXTRAS_PAM_SUDO_LOCAL"
    run sudo sed -i '' 's/^#auth/auth/' "$_EXTRAS_PAM_SUDO_LOCAL"
    success "Touch ID for sudo enabled"
  else
    # A sudo_local we didn't create and can't recognize — leave it alone.
    warn "$_EXTRAS_PAM_SUDO_LOCAL exists without an active pam_tid line."
    warn "Add \`auth       sufficient     pam_tid.so\` to it yourself; not touching your file."
  fi

  # 2. Credential cache drop-in, syntax-checked before it goes live (a bad
  # sudoers file can lock you out of sudo entirely).
  local tmpf
  tmpf="$(mktemp)"
  cat > "$tmpf" <<EOF
# Installed by \`omacase extras sudo-touchid\` — revert with \`omacase extras sudo-touchid off\`.
Defaults timestamp_timeout=$_EXTRAS_SUDO_TIMEOUT_MIN
Defaults timestamp_type=global
EOF
  visudo -c -q -f "$tmpf" || { rm -f "$tmpf"; abort "generated sudoers drop-in failed validation"; }
  run sudo install -m 0440 -o root -g wheel "$tmpf" "$_EXTRAS_SUDOERS_FILE"
  rm -f "$tmpf"
  success "sudo credential cache: ${_EXTRAS_SUDO_TIMEOUT_MIN} min, shared across terminals"
}

_extra_sudo_touchid_off() {
  step "Reverting sudo-touchid"
  if [ -f "$_EXTRAS_SUDOERS_FILE" ]; then
    run sudo rm -f "$_EXTRAS_SUDOERS_FILE"
    success "sudo credential cache back to macOS defaults"
  fi
  # Only delete sudo_local when pam_tid is its sole active line — i.e. it still
  # looks like the file this extra created. Anything else is user-managed.
  if [ -f "$_EXTRAS_PAM_SUDO_LOCAL" ]; then
    if [ "$(grep -Ev '^#|^$' "$_EXTRAS_PAM_SUDO_LOCAL")" = "$(grep -E '^auth[[:space:]].*pam_tid\.so' "$_EXTRAS_PAM_SUDO_LOCAL")" ]; then
      run sudo rm -f "$_EXTRAS_PAM_SUDO_LOCAL"
      success "Touch ID for sudo disabled"
    else
      warn "$_EXTRAS_PAM_SUDO_LOCAL has other customizations — remove pam_tid from it yourself."
    fi
  fi
}
