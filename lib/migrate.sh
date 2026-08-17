# shellcheck shell=bash
# `omacase migrate` — apply pending one-time migrations. Run automatically by
# `omacase update`.
#
# WHY THIS EXISTS: the declarative apply (symlinks + `brew bundle` + `defaults`)
# only ever ADDS. `brew bundle` never uninstalls a package dropped from the
# Brewfile; re-linking dotfiles never deletes a renamed config; `defaults` keys
# get overwritten but never removed. Migrations are the imperative complement —
# small, ordered, idempotent scripts that bring an *existing* install forward so
# every machine converges to the same state regardless of when it was set up.
#
# SCOPE / SAFETY: destructive cleanup requires evidence that Omacase owns the
# target (for example, a symlink into OMACASE_ROOT/OMACASE_DATA or a project
# marker). An exact name plus "is it present" is not ownership evidence. There is
# NO `brew bundle cleanup`, and migrations never uninstall Homebrew packages.
#
# MODEL: each migrations/<id>.sh defines a single migrate(); <id> is a sortable
# timestamp-prefixed slug (YYYYMMDD-slug) so lexical order == chronological order.
# A high-water mark in $OMACASE_STATE/migrations-last records the last applied id;
# anything newer runs, in order, and the marker advances after each success.
# `omacase install` stamps a fresh machine with the greatest migration id shipped
# in its checkout: a fresh install already IS the declarative end-state, so every
# migration present in that tree must be skipped. Deriving the baseline from the
# tree (rather than the client's clock) keeps this true across clock skew and time
# zones. When the migration directory is empty, a fixed post-squash sentinel is
# used instead.
# (Limitation, acceptable for a linear repo: an id added *below* the marker later
# is skipped. Revisit only if migrations ever grow Omarchy-large.)
#
# AUTHORING RULES (each migration is a subshell under `set -e`):
# - REQUIRED convergence work must propagate failure — plain `run cmd`, no
#   `|| warn`. The runner halts, keeps the marker, and retries on the next
#   `omacase update`; masking the failure with `|| warn` would advance the
#   marker and silently skip the retry forever.
# - BEST-EFFORT cleanup (nice-to-have, safe to lose) may use `|| warn`, and the
#   warn text should say it is best-effort.
# - Migrations must stay idempotent and prove ownership before destructive work;
#   an exact Omacase-shipped name alone is not enough.
# - Migrations MUST NOT uninstall Homebrew formulae or casks. Presence and an old
#   install marker do not prove that Omacase installed a package: a machine may
#   have skipped the release that introduced it, or the user may own it. Leave a
#   dropped package installed and tell the user how to remove it explicitly.

_migrations_marker() { printf '%s' "$OMACASE_STATE/migrations-last"; }

# This is the greatest id removed by the 2026-08-16 squash. Reusing that exact
# high-water mark skips all squashed history while still allowing a later id —
# including a full-timestamp id authored on the same day — to run.
_MIGRATIONS_SQUASH_BASELINE=20260816-yazi-replaces-ranger

_migrations_latest_shipped_id() {
  local LC_COLLATE=C
  local dir="$OMACASE_ROOT/migrations" f id
  local latest="$_MIGRATIONS_SQUASH_BASELINE"
  if [ -d "$dir" ]; then
    for f in "$dir"/*.sh; do
      [ -e "$f" ] || break
      id="$(basename "$f" .sh)"
      [[ "$id" > "$latest" ]] && latest="$id"
    done
  fi
  printf '%s\n' "$latest"
}

# Stamp a fresh install as already converged (no marker → write one). The
# baseline is repository state, not wall-clock state: every migration present in
# the installed checkout sorts at or below it and therefore cannot replay.
_migrations_baseline() {
  local marker baseline
  marker="$(_migrations_marker)"
  [ -s "$marker" ] && return 0
  baseline="$(_migrations_latest_shipped_id)"
  ensure_state_dir
  if is_dryrun; then
    # `omacase update` runs migrations later in the same process. Carry the
    # would-be marker in memory so dry-run previews the same skip decisions as a
    # real install without writing state.
    OMACASE_MIGRATIONS_BASELINE="$baseline"
    log "[dry-run] would baseline migrations marker at $baseline"
  else
    printf '%s\n' "$baseline" > "$marker"
  fi
}

omacase_migrate() {
  ensure_brew_env
  local LC_COLLATE=C   # byte-order id sorting/compare, independent of the user's locale
  local dir="$OMACASE_ROOT/migrations"
  [ -d "$dir" ] || { info "No migrations directory."; return 0; }

  local marker; marker="$(_migrations_marker)"
  local last;   last="$(cat "$marker" 2>/dev/null || echo)"
  [ -n "$last" ] || last="${OMACASE_MIGRATIONS_BASELINE:-}"
  ensure_state_dir

  local f id ran=0
  for f in "$dir"/*.sh; do
    [ -e "$f" ] || break                       # glob didn't expand → no migrations
    id="$(basename "$f" .sh)"
    # Skip anything at or below the high-water mark (already applied).
    if [ -n "$last" ] && { [ "$id" = "$last" ] || [[ "$id" < "$last" ]]; }; then
      continue
    fi
    step "migration: $id"
    # Run in a subshell so a migration's `set -e`/exit can't kill the runner, and
    # its migrate() definition can't leak. common.sh helpers are inherited.
    # shellcheck source=/dev/null
    if ( set -e; unset -f migrate 2>/dev/null; source "$f"; migrate ); then
      is_dryrun || echo "$id" > "$marker"      # don't advance the marker in dry-run
      ran=$((ran + 1))
    else
      warn "migration '$id' failed — halting; it will retry on the next \`omacase update\`."
      return 1
    fi
  done

  if [ "$ran" -gt 0 ]; then success "$ran migration(s) applied."; else info "No pending migrations."; fi
}
