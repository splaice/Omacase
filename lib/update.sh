# shellcheck shell=bash
# `omacase update` — move the payload to the selected channel, then re-run
# the install engine.
#
#   OMACASE_CHANNEL=stable (default)  fetch tags, check out the greatest v*
#   OMACASE_CHANNEL=dev               pull --ff-only on the default branch
#
#   omacase update --check            fetch and print pending changes; no checkout
#   omacase update --rollback         return to the SHA recorded before the
#                                     last payload switch, then re-run install

OMACASE_CHANNEL="${OMACASE_CHANNEL:-stable}"

_latest_release_tag() {
  git -C "$OMACASE_ROOT" tag --list 'v*' --sort=-v:refname | head -1
}

_current_exact_tag() {
  git -C "$OMACASE_ROOT" describe --tags --exact-match 2>/dev/null || true
}

_update_record_prev() {
  is_dryrun && return 0
  mkdir -p "$OMACASE_STATE"
  git -C "$OMACASE_ROOT" rev-parse HEAD > "$OMACASE_STATE/update-prev"
}

_update_target_ref() {
  if [ "$OMACASE_CHANNEL" = dev ]; then
    git -C "$OMACASE_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null \
      || printf '%s\n' origin/main
  else
    _latest_release_tag
  fi
}

_update_check() {
  [ -d "$OMACASE_ROOT/.git" ] || abort "No git checkout at $OMACASE_ROOT."
  if [ "$OMACASE_CHANNEL" = dev ]; then
    git -C "$OMACASE_ROOT" fetch origin
  else
    git -C "$OMACASE_ROOT" fetch --tags origin
  fi
  local target current tag
  target="$(_update_target_ref)"
  current="$(git -C "$OMACASE_ROOT" rev-parse --short HEAD)"
  [ -n "$target" ] || abort "No update target (channel=$OMACASE_CHANNEL). Cut a v* tag or set OMACASE_CHANNEL=dev."
  tag="$(_current_exact_tag)"
  printf 'channel: %s\n' "$OMACASE_CHANNEL"
  if [ -n "$tag" ]; then
    printf 'current: %s (%s)\n' "$current" "$tag"
  else
    printf 'current: %s\n' "$current"
  fi
  printf 'target:  %s\n' "$target"
  if [ "$(git -C "$OMACASE_ROOT" rev-parse HEAD)" = "$(git -C "$OMACASE_ROOT" rev-parse "$target^{commit}")" ]; then
    info "Already up to date."
    return 0
  fi
  local n
  n="$(git -C "$OMACASE_ROOT" rev-list --count "HEAD..$target" 2>/dev/null || echo 0)"
  printf 'pending: %s commit(s)\n' "$n"
  git -C "$OMACASE_ROOT" log --oneline "HEAD..$target"
  git -C "$OMACASE_ROOT" diff --stat "HEAD..$target"
}

_update_rollback() {
  local prev="$OMACASE_STATE/update-prev"
  [ -f "$prev" ] || abort "No previous update SHA recorded. (omacase update --rollback is one level deep.)"
  local sha
  sha="$(cat "$prev")"
  [ -n "$sha" ] || abort "Empty rollback SHA in $prev."
  warn "Rolling back payload to $sha"
  git -C "$OMACASE_ROOT" checkout -q "$sha" \
    || abort "git checkout $sha failed."
  is_dryrun && return 0
  exec "$OMACASE_ROOT/bin/omacase" install
}

_update_remote_default_branch() {
  local ref
  ref="$(git -C "$OMACASE_ROOT" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  ref="${ref#origin/}"
  printf '%s\n' "${ref:-main}"
}

# stable leaves a detached tag checkout. Dev must attach to the remote
# default branch without reset --hard / checkout -B (those discard work).
_update_attach_dev() {
  local branch
  branch="$(_update_remote_default_branch)"
  if is_dryrun; then
    log "[dry-run] would attach to origin/$branch and fast-forward"
    return 0
  fi
  git -C "$OMACASE_ROOT" fetch origin "$branch" \
    || abort "git fetch origin $branch failed."
  if git -C "$OMACASE_ROOT" symbolic-ref -q HEAD >/dev/null; then
    git -C "$OMACASE_ROOT" merge --ff-only "origin/$branch" \
      || abort "git merge --ff-only origin/$branch failed (local changes?). Resolve it before updating."
    return
  fi
  info "Attaching detached checkout to origin/$branch (dev channel)…"
  if git -C "$OMACASE_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$OMACASE_ROOT" checkout -q "$branch" \
      || abort "Could not check out $branch (local changes?). Resolve them or stay on OMACASE_CHANNEL=stable."
  else
    git -C "$OMACASE_ROOT" checkout -q --track "origin/$branch" \
      || abort "Could not attach to origin/$branch (local changes?). Resolve them or stay on OMACASE_CHANNEL=stable."
  fi
  git -C "$OMACASE_ROOT" merge --ff-only "origin/$branch" \
    || abort "git merge --ff-only origin/$branch failed (local changes?). Resolve it before updating."
}

_update_switch_payload() {
  # A legacy login-items edit dirties a tracked file, which blocks both the dev
  # ff-only pull and the stable tag checkout — recover it before any movement.
  _recover_legacy_login_items "$OMACASE_ROOT"
  case "$OMACASE_CHANNEL" in
    dev)
      step "Pulling latest omacase (dev channel)"
      _update_record_prev
      _update_attach_dev ;;
    stable)
      step "Fetching omacase release tags (stable channel)"
      run git -C "$OMACASE_ROOT" fetch --tags origin \
        || abort "git fetch --tags failed."
      local tag current
      tag="$(_latest_release_tag)"
      [ -n "$tag" ] || abort "No v* release tags found. Cut a release or set OMACASE_CHANNEL=dev."
      current="$(_current_exact_tag)"
      if [ "$tag" = "$current" ]; then
        info "Already on $tag"
      else
        _update_record_prev
        run git -C "$OMACASE_ROOT" checkout -q "$tag" \
          || abort "git checkout $tag failed."
      fi ;;
    *)
      abort "Unknown OMACASE_CHANNEL='$OMACASE_CHANNEL' (use stable or dev)." ;;
  esac
}

omacase_update() {
  ensure_brew_env
  dryrun_banner
  case "${1:-}" in
    --check) _update_check; return ;;
    --rollback) _update_rollback; return ;;
    "" ) ;;
    *) abort "unknown update flag: $1 (try --check or --rollback)" ;;
  esac
  if [ -d "$OMACASE_ROOT/.git" ] && [ -z "${OMACASE_UPDATE_REEXECED:-}" ]; then
    _update_switch_payload
    # Everything sourced so far (common.sh, this file) came from the pre-switch
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
    warn "mise upgrade converges to the pinned versions; set OMACASE_SKIP_MISE_UPGRADE=1 to skip."
    require "mise upgrade" mise upgrade
  fi
  step "Upgrading outdated formulae & casks"
  # Skip casks marked auto_updates (WhatsApp, Chrome, …): those apps update
  # themselves in-app, and brew re-downloading them goes through the vendor's
  # versioned URLs — the flakiest channel there is (rotated/retracted builds
  # 500/404 routinely). A vendor hiccup must not mark the whole update PARTIAL
  # over an app that was never brew's to update. Exported (not `env`-prefixed)
  # so `run`/`require` still invoke `brew` as a plain word; update is the last
  # step of the process, so the export cannot leak anywhere that matters.
  export HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1
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
