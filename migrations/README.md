# Migrations

One-time, ordered, idempotent scripts that bring an **existing** install
forward. Fresh installs never run them: `omacase install` writes an
install-time baseline marker, because a fresh install already is the
declarative end-state (Brewfile + dotfiles + defaults).

The history was squashed on 2026-08-16 (pre-release, zero users). The model,
runner, and authoring rules live in `lib/migrate.sh` — read its header before
adding a file here. In short:

- `migrations/<YYYYMMDD[HHMMSS]>-slug.sh` defining a single `migrate()`.
- Required convergence work propagates failure (no `|| warn`) so the runner
  halts, keeps the marker, and retries on the next `omacase update`.
- `|| warn` is reserved for best-effort cleanup that is safe to lose.
- Touch only exact Omacase-shipped names, guarded by "is it actually present".
