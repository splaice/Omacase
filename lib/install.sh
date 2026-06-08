# shellcheck shell=bash
# `macarchy install` — the idempotent setup engine. Safe to re-run; it is the
# same engine `macarchy update` calls.

macarchy_install() {
  ensure_brew_env

  step "1/5  Packages & apps (brew bundle)"
  brew bundle --file="$MACARCHY_ROOT/Brewfile" || warn "Some brew items failed; re-run later."

  step "2/5  Dotfiles (chezmoi)"
  _apply_dotfiles

  step "3/5  macOS defaults"
  bash "$MACARCHY_ROOT/macos/defaults.sh"

  step "4/5  Theme"
  source "$MACARCHY_ROOT/lib/theme.sh"
  macarchy_theme "$(cat "$MACARCHY_STATE/theme" 2>/dev/null || echo catppuccin-mocha)"

  step "5/5  Window manager + services"
  source "$MACARCHY_ROOT/lib/wm.sh"
  macarchy_wm "$(cat "$MACARCHY_STATE/wm" 2>/dev/null || echo aerospace)"

  step "Done"
  success "macarchy installed."
  warn "Next: run \`macarchy doctor\` and grant Accessibility to AeroSpace, SketchyBar, Karabiner & Raycast."
  warn "macOS requires those grants by hand — no installer can click them for you."
}

_apply_dotfiles() {
  have chezmoi || { warn "chezmoi missing (brew step may have failed) — skipping dotfiles."; return; }
  # Point chezmoi at this repo's source dir; apply without clobbering silently.
  chezmoi init --apply --source "$MACARCHY_ROOT/home" || warn "chezmoi apply had conflicts; run \`chezmoi diff\`."
}

macarchy_uninstall() {
  warn "This removes macarchy-managed dotfiles & launchd services."
  warn "It does NOT uninstall your Homebrew apps."
  confirm "Proceed?" || { info "Cancelled."; return; }
  source "$MACARCHY_ROOT/lib/wm.sh"; _wm_stop_all || true
  have chezmoi && chezmoi purge --force 2>/dev/null || true
  success "Removed. Your apps remain; \`brew bundle cleanup\` to prune them."
}
