# shellcheck shell=bash
# `macarchy update` — pull latest payload, then re-run the install engine.

macarchy_update() {
  ensure_brew_env
  dryrun_banner
  if [ -d "$MACARCHY_ROOT/.git" ]; then
    step "Pulling latest macarchy"
    run git -C "$MACARCHY_ROOT" pull --ff-only || warn "git pull failed (local changes?). Continuing."
  fi
  step "Updating Homebrew"
  run brew update || true
  source "$MACARCHY_ROOT/lib/install.sh"
  macarchy_install
  step "Upgrading outdated formulae & casks"
  run brew upgrade || warn "Some upgrades failed."
  success "macarchy up to date."
}
