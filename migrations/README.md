# Migrations

One-time, ordered, idempotent scripts that bring an **existing** install
forward. Fresh installs never run them: `omacase install` records the greatest
migration id shipped in its checkout, because a fresh install already is the
declarative end-state (Brewfile + dotfiles + defaults). An empty migration
directory uses the fixed post-squash sentinel from `lib/migrate.sh`.

The history was squashed on 2026-08-16 (pre-release, zero users). The model,
runner, and authoring rules live in `lib/migrate.sh` — read its header before
adding a file here. In short:

- `migrations/<YYYYMMDD[HHMMSS]>-slug.sh` defining a single `migrate()`.
- Required convergence work propagates failure (no `|| warn`) so the runner
  halts, keeps the marker, and retries on the next `omacase update`.
- `|| warn` is reserved for best-effort cleanup that is safe to lose.
- Require verifiable Omacase ownership before destructive cleanup (an owned
  symlink or project marker); exact name and presence alone are insufficient.
- Never automatically uninstall a Homebrew formula or cask. An install marker
  and `brew list` do not prove package ownership when a machine can skip
  releases. Leave dropped packages installed and make removal explicit.
