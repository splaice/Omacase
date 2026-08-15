# shellcheck shell=bash
# `omacase doctor` — diagnose the things an installer can't fix automatically:
# TCC permission grants and missing tooling. Deep-links to the right Settings pane.

omacase_doctor() {
  ensure_brew_env
  local issues=0

  step "Tooling"
  for c in brew gum omniwmctl; do
    if have "$c"; then success "$c installed"; else error "$c missing — run \`omacase install\`"; issues=$((issues + 1)); fi
  done

  step "Command on PATH (\`omacase\`)"
  local bindir link want; bindir="$(_omacase_bindir)"; want="$OMACASE_ROOT/bin/omacase"
  if [ -z "$bindir" ]; then
    warn "No Homebrew bin dir found — can't link \`omacase\` onto PATH."; issues=$((issues + 1))
  else
    link="$bindir/omacase"
    if [ "$(readlink "$link" 2>/dev/null)" = "$want" ]; then
      success "\`omacase\` → $link"
    elif [ -e "$link" ] || [ -L "$link" ]; then
      warn "$link is unrelated to this checkout — leaving it alone."; issues=$((issues + 1))
    else
      warn "\`omacase\` not linked onto PATH — repairing → $link"
      run ln -s "$want" "$link"
      is_dryrun || success "linked \`omacase\` → $link"
    fi
  fi

  step "Shell completion (zsh)"
  local zfunc comp; zfunc="$(_omacase_zfuncdir)"; comp="$OMACASE_ROOT/completions/_omacase"
  if [ -z "$zfunc" ]; then
    warn "No Homebrew prefix found — can't link zsh completion."; issues=$((issues + 1))
  elif [ "$(readlink "$zfunc/_omacase" 2>/dev/null)" = "$comp" ]; then
    success "_omacase → $zfunc/_omacase  (omacase <Tab> completes; compinit runs via ~/.zshrc)"
  elif [ -e "$zfunc/_omacase" ] || [ -L "$zfunc/_omacase" ]; then
    warn "$zfunc/_omacase is unrelated to this checkout — leaving it alone."; issues=$((issues + 1))
  else
    warn "zsh completion not linked — repairing → $zfunc/_omacase"
    run mkdir -p "$zfunc"
    run ln -s "$comp" "$zfunc/_omacase"
    is_dryrun || success "linked _omacase → $zfunc/_omacase  (open a new shell to pick it up)"
  fi
  # Group-writable dirs above an fpath entry make compinit prompt "insecure
  # directories?" on every new shell (brew installs can re-add go-w to share/).
  if [ -n "$zfunc" ]; then
    local share="${zfunc%/zsh/site-functions}" insecure
    insecure="$(find "$share" "$share/zsh" "$zfunc" "$share/zsh-completions" -maxdepth 0 -perm +022 2>/dev/null)"
    if [ -n "$insecure" ]; then
      warn "group/world-writable completion dirs (compinit will nag) — fixing: $insecure"
      local d
      while IFS= read -r d; do
        [ -n "$d" ] && run chmod go-w "$d" || true
      done <<< "$insecure"
    else
      success "completion dirs pass compaudit (no group-writable parents)"
    fi
  fi

  step "Backups"
  local last; last="$(cat "$OMACASE_STATE/last-backup" 2>/dev/null)"
  if [ -n "$last" ]; then success "latest snapshot: $last  (omacase restore to roll back)"
  else info "no backups yet (created automatically on first install)"; fi

  step "Window manager"
  # shellcheck source=/dev/null
  source "$OMACASE_ROOT/lib/wm.sh"
  if ! pgrep -x OmniWM >/dev/null; then
    warn "OmniWM not running — \`omacase wm\`"; issues=$((issues + 1))
  elif _wm_ipc_ready; then
    success "OmniWM running and IPC healthy"
  else
    warn "OmniWM is running but IPC is unavailable — enable IPC in OmniWM settings."
    issues=$((issues + 1))
  fi
  step "macOS window management"
  local spans stage_manager
  spans="$(defaults read com.apple.spaces spans-displays 2>/dev/null || echo 1)"
  if [ "$spans" = 0 ]; then
    success "Displays have separate Spaces (OmniWM requirement)"
  else
    warn "Displays have separate Spaces is not active. Omacase set it, but you must log out once."
    issues=$((issues + 1))
  fi
  stage_manager="$(defaults read com.apple.WindowManager GloballyEnabled 2>/dev/null || echo 0)"
  if [ "$stage_manager" = 0 ]; then
    success "Stage Manager is disabled (all tiles can remain visible)"
  else
    warn "Stage Manager is active and can hide OmniWM tiles. Re-run \`omacase install\` or disable it in Control Center."
    issues=$((issues + 1))
  fi

  step "Appearance sync (theme ⇄ macOS Light/Dark)"
  if can_set_appearance; then
    success "Terminal can drive macOS appearance — theme switches will flip Light/Dark."
  else
    warn "Terminal can't control System Events, so theme switches can't flip macOS Light/Dark."
    warn "  Grant it: System Settings → Privacy & Security → Automation → (your terminal) → System Events."
    issues=$((issues + 1))
  fi

  step "Permissions (macOS requires these by hand)"
  cat <<'EOF'
  These need a manual toggle in System Settings → Privacy & Security.
  No script can grant them — that's the OS security model, by design.

    Accessibility      : OmniWM
    Input Monitoring   : only if you enable OmniWM's optional system Hyper key
    Automation         : terminal → System Events (theme Light/Dark sync)
    Full Disk Access   : (optional) terminal, for some defaults writes
EOF

  step "Launcher (Spotlight — built in, no third-party app)"
  cat <<'EOF'
  macOS Spotlight is the launcher / command palette. On Tahoe it also has a
  clipboard manager, Actions (App Intents), and auto-learned Quick Keys.
    ⌘ Space        →  Spotlight (launcher / search / actions / clipboard)
    ⌃⌘ Space       →  Emoji & Symbols (Character Viewer)
    ⌘ Tab          →  Switch apps (macOS app switcher)
  If ⌘Space doesn't open Spotlight (e.g. a launcher had taken it), re-enable it:
  System Settings → Keyboard → Keyboard Shortcuts → Spotlight → "Show Spotlight search".
  OmniWM owns the window-management shortcuts; Omacase installs no launcher
  applications and does not intercept normal keyboard input.
EOF
  if confirm "Open the Accessibility settings pane now?"; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
  fi

  step "Summary"
  if [ "$issues" -eq 0 ]; then success "No automated issues found. Verify the manual grants above."
  else warn "$issues issue(s) detected above."; fi
}
