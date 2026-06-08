# shellcheck shell=bash
# `omacase install` — the idempotent setup engine. Safe to re-run; it is the
# same engine `omacase update` calls.

omacase_install() {
  ensure_brew_env
  dryrun_banner

  step "1/5  Packages & apps (brew bundle)"
  run brew bundle --file="$OMACASE_ROOT/Brewfile" || warn "Some brew items failed; re-run later."

  step "2/5  Dotfiles (chezmoi)"
  _apply_dotfiles

  step "3/5  macOS defaults"
  bash "$OMACASE_ROOT/macos/defaults.sh"   # honors OMACASE_DRYRUN itself

  step "4/5  Theme"
  source "$OMACASE_ROOT/lib/theme.sh"
  omacase_theme "$(cat "$OMACASE_STATE/theme" 2>/dev/null || echo catppuccin-mocha)"

  step "5/5  Window manager + services"
  source "$OMACASE_ROOT/lib/wm.sh"
  omacase_wm "$(cat "$OMACASE_STATE/wm" 2>/dev/null || echo aerospace)"

  step "Done"
  success "omacase installed."
  warn "Next: run \`omacase doctor\` and grant Accessibility to AeroSpace, SketchyBar, Karabiner & Raycast."
  warn "macOS requires those grants by hand — no installer can click them for you."
}

_apply_dotfiles() {
  if is_dryrun; then
    run chezmoi init --apply --source "$OMACASE_ROOT/home"
    return
  fi
  have chezmoi || { warn "chezmoi missing (brew step may have failed) — skipping dotfiles."; return; }
  # Point chezmoi at this repo's source dir; apply without clobbering silently.
  chezmoi init --apply --source "$OMACASE_ROOT/home" || warn "chezmoi apply had conflicts; run \`chezmoi diff\`."
}

omacase_uninstall() {
  warn "This removes omacase-managed dotfiles & launchd services."
  warn "It does NOT uninstall your Homebrew apps."
  confirm "Proceed?" || { info "Cancelled."; return; }
  source "$OMACASE_ROOT/lib/wm.sh"; _wm_stop_all || true
  have chezmoi && chezmoi purge --force 2>/dev/null || true
  success "Removed. Your apps remain; \`brew bundle cleanup\` to prune them."
}
