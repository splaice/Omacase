# shellcheck shell=bash
# `omacase update` — pull latest payload, then re-run the install engine.

omacase_update() {
  ensure_brew_env
  dryrun_banner
  if [ -d "$OMACASE_ROOT/.git" ] && [ -z "${OMACASE_UPDATE_REEXECED:-}" ]; then
    step "Pulling latest omacase"
    _recover_legacy_login_items "$OMACASE_ROOT"
    run git -C "$OMACASE_ROOT" pull --ff-only || abort "git pull failed (local changes?). Resolve it before updating."
    # Everything sourced so far (common.sh, this file) came from the pre-pull
    # checkout; re-exec into the fresh tree so the rest of the update runs a
    # single, consistent version instead of a mix of old and new lib files.
    if ! is_dryrun; then
      OMACASE_UPDATE_REEXECED=1 exec "$OMACASE_ROOT/bin/omacase" update "$@"
    fi
  fi
  step "Updating Homebrew"
  require "brew update" brew update
  source "$OMACASE_ROOT/lib/install.sh"
  # Nested so install does not call converged (the outer report does). This is a
  # simple command: set -e stays in effect inside omacase_install. Ledgered
  # require() failures still return 0 and later upgrade steps still run.
  OMACASE_NESTED_INSTALL=1
  omacase_install
  # One-time imperative cleanup the declarative apply can't do (e.g. uninstall a
  # dropped cask). Idempotent + tracked; failure retries on the next update.
  source "$OMACASE_ROOT/lib/migrate.sh"
  omacase_migrate || OMACASE_INCOMPLETE+=("migrations")
  if [ -n "${OMACASE_SKIP_MISE_UPGRADE:-}" ]; then
    info "Skipping mise tool upgrades (OMACASE_SKIP_MISE_UPGRADE is set)."
  elif have mise; then
    step "Upgrading mise tools (node + npm CLIs)"
    warn "mise tools include npm packages pinned to latest; set OMACASE_SKIP_MISE_UPGRADE=1 to skip."
    require "mise upgrade" mise upgrade
  fi
  step "Upgrading outdated formulae & casks"
  require "brew upgrade" brew upgrade
  converged "omacase up to date"
}

# `omacase outdated` — print the number of outdated Homebrew packages.
# NO_AUTO_UPDATE keeps it read-only and fast; `omacase update` does the fetch.
omacase_outdated() {
  ensure_brew_env
  local n
  # `grep -c` exits 1 on zero matches, hence the guarded pipeline.
  n="$(/bin/zsh -lc 'HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --quiet 2>/dev/null | grep -c "." || true' 2>/dev/null)"
  n="${n//[^0-9]/}"; n="${n:-0}"
  # Future: add omacase self-updates here once omacase ships versioned releases
  # (compare VERSION to the latest tag) and fold into the count.
  echo "$n"
}
