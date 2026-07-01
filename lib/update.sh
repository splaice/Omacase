# shellcheck shell=bash
# `omacase update` — pull latest payload, then re-run the install engine.

omacase_update() {
  ensure_brew_env
  dryrun_banner
  if [ -d "$OMACASE_ROOT/.git" ] && [ -z "${OMACASE_UPDATE_REEXECED:-}" ]; then
    step "Pulling latest omacase"
    run git -C "$OMACASE_ROOT" pull --ff-only || abort "git pull failed (local changes?). Resolve it before updating."
    # Everything sourced so far (common.sh, this file) came from the pre-pull
    # checkout; re-exec into the fresh tree so the rest of the update runs a
    # single, consistent version instead of a mix of old and new lib files.
    if ! is_dryrun; then
      OMACASE_UPDATE_REEXECED=1 exec "$OMACASE_ROOT/bin/omacase" update "$@"
    fi
  fi
  step "Updating Homebrew"
  run brew update || true
  source "$OMACASE_ROOT/lib/install.sh"
  omacase_install
  # One-time imperative cleanup the declarative apply can't do (e.g. uninstall a
  # dropped cask). Idempotent + tracked; failure halts migrations but not update.
  source "$OMACASE_ROOT/lib/migrate.sh"
  omacase_migrate || warn "Some migrations did not complete — they'll retry next update."
  if [ -n "${OMACASE_SKIP_MISE_UPGRADE:-}" ]; then
    info "Skipping mise tool upgrades (OMACASE_SKIP_MISE_UPGRADE is set)."
  elif have mise; then
    step "Upgrading mise tools (node + npm CLIs)"
    warn "mise tools include npm packages pinned to latest; set OMACASE_SKIP_MISE_UPGRADE=1 to skip."
    run mise upgrade || warn "mise upgrade had issues."   # bumps latest-pinned npm CLIs
  fi
  step "Upgrading outdated formulae & casks"
  run brew upgrade || warn "Some upgrades failed."
  success "omacase up to date."
}

# `omacase outdated` — print the number of outdated Homebrew packages, and (best
# effort) paint the SketchyBar `update` indicator. Drives the bottom-bar
# update-available icon, but also useful on its own.
#
# brew is run inside a fresh login shell on purpose: when the SketchyBar daemon
# spawns brew directly, brew dies in Hardware::CPU.cores ("undefined method
# 'success?' for nil"); a login-shell process sidesteps that. NO_AUTO_UPDATE
# keeps it read-only and fast — `omacase update` does the actual fetch/upgrade.
omacase_outdated() {
  ensure_brew_env
  local n
  # `grep -c` exits 1 on zero matches; without the `|| true` that status would
  # propagate out of the substitution and set -e would kill us before the
  # drawing=off branch — leaving the bar's update indicator stuck on.
  n="$(/bin/zsh -lc 'HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --quiet 2>/dev/null | grep -c "." || true' 2>/dev/null)"
  n="${n//[^0-9]/}"; n="${n:-0}"
  # Future: add omacase self-updates here once omacase ships versioned releases
  # (compare VERSION to the latest tag) and fold into the count.

  if have sketchybar; then
    source "$HOME/.config/sketchybar/theme.sh" 2>/dev/null || true
    if [ "$n" -gt 0 ]; then
      sketchybar --set update drawing=on icon.color="${ACCENT:-0xff89b4fa}" \
        label="$n" label.color="${LABEL_COLOR:-0xffcdd6f4}" 2>/dev/null || true
    else
      sketchybar --set update drawing=off 2>/dev/null || true
    fi
  fi
  echo "$n"
}
