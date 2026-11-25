# shellcheck shell=bash
# `omacase doctor` — diagnose the things an installer can't fix automatically:
# TCC permission grants and missing tooling. Deep-links to the right Settings pane.

omacase_doctor() {
  ensure_brew_env
  local issues=0

  step "Tooling"
  for c in brew gum; do
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

    Accessibility      : Sol; Ghostty (⌃Esc quick terminal, overlay helpers)
    Automation         : terminal → System Events (theme Light/Dark sync)
    Full Disk Access   : (optional) terminal, for some defaults writes
EOF

  step "Launcher (Sol — replaces Spotlight on ⌘Space)"
  if [ -d /Applications/Sol.app ]; then success "Sol installed"
  else warn "Sol not installed — run: brew install --cask sol"; issues=$((issues + 1)); fi
  if /usr/libexec/PlistBuddy -c 'Print :AppleSymbolicHotKeys:64:enabled' \
       "$HOME/Library/Preferences/com.apple.symbolichotkeys.plist" 2>/dev/null | grep -qiE '^(1|true)$'; then
    warn "Spotlight still owns ⌘Space — re-run macos/defaults.sh (omacase install)"
    issues=$((issues + 1))
  else success "Spotlight's ⌘Space shortcut is released"; fi
  cat <<'EOF'
  Sol is the launcher / command palette (apps, clipboard, emoji, scratchpad).
    ⌘ Space        →  Sol (pick "⌘ Space" in Sol's onboarding or Settings → General)
    ⌃⌘ Space       →  Emoji & Symbols (Character Viewer)
    ⌘ Tab          →  Switch apps (macOS app switcher)
  Sol needs Accessibility access and launches itself at login (Sol setting).
  To go back to Spotlight: System Settings → Keyboard → Keyboard Shortcuts →
  Spotlight → "Show Spotlight search", and set Sol to another hotkey.
EOF
  if confirm "Open the Accessibility settings pane now?"; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
  fi

  step "Summary"
  if [ "$issues" -eq 0 ]; then success "No automated issues found. Verify the manual grants above."
  else warn "$issues issue(s) detected above."; fi
}
