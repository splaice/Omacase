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
# SCOPE / SAFETY: a migration only ever touches things OMACASE itself shipped and
# later dropped, by EXACT name, each guarded by "is it actually present". There
# is NO `brew bundle cleanup` and nothing is removed merely for being absent from
# the Brewfile — so a user's own `brew install`s are never affected.
#
# MODEL: each migrations/<id>.sh defines a single migrate(); <id> is a sortable
# timestamp-prefixed slug (YYYYMMDD-slug) so lexical order == chronological order.
# A high-water mark in $OMACASE_STATE/migrations-last records the last applied id;
# anything newer runs, in order, and the marker advances after each success.
# Because every migration is idempotent, the marker is only ordering + speed — a
# fresh machine can safely run the whole history (each finds nothing to do).
# (Limitation, acceptable for a linear repo: an id added *below* the marker later
# is skipped. Revisit only if migrations ever grow Omarchy-large.)

_migrations_marker() { printf '%s' "$OMACASE_STATE/migrations-last"; }

omacase_migrate() {
  ensure_brew_env
  local LC_COLLATE=C   # byte-order id sorting/compare, independent of the user's locale
  local dir="$OMACASE_ROOT/migrations"
  [ -d "$dir" ] || { info "No migrations directory."; return 0; }

  local marker; marker="$(_migrations_marker)"
  local last;   last="$(cat "$marker" 2>/dev/null || echo)"
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
