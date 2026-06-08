# shellcheck shell=bash
# `omacase update` — pull latest payload, then re-run the install engine.

omacase_update() {
  ensure_brew_env
  dryrun_banner
  if [ -d "$OMACASE_ROOT/.git" ]; then
    step "Pulling latest omacase"
    run git -C "$OMACASE_ROOT" pull --ff-only || warn "git pull failed (local changes?). Continuing."
  fi
  step "Updating Homebrew"
  run brew update || true
  source "$OMACASE_ROOT/lib/install.sh"
  omacase_install
  step "Upgrading outdated formulae & casks"
  run brew upgrade || warn "Some upgrades failed."
  success "omacase up to date."
}
