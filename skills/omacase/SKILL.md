---
name: omacase
description: Install, update, theme, back up, and diagnose an opinionated macOS environment with the omacase CLI.
---

# Omacase

Use the current checkout's `bin/omacase` (or `omacase` when linked) for changes
to the Omacase-managed Mac environment.

## Main operations

- `omacase install` — idempotently apply packages, dotfiles, defaults, theme,
  and the Sol launcher (⌘Space).
- `omacase update` — pull, reapply, migrate, and update packages/tools.
- `omacase doctor` — inspect tooling, permissions, command links, backups,
  appearance sync, and the Sol launcher.
- `omacase keybinds` — render the project key reference in the terminal.
- `omacase theme [name]`, `palette [name]`, `wallpaper [...]` — visual system.
- `omacase backup [label]`, `restore [id]` — reversible configuration snapshots.
- `omacase migrate` — apply exact, tracked one-time cleanups.

## Ownership

Omacase owns files linked from `home/`, its generated theme cache, package
declarations, and macOS defaults. Window management is stock macOS; Omacase
ships no window manager and no global window shortcuts.

## Safety

- Preview broad changes with `OMACASE_DRYRUN=1 omacase install`.
- Preserve non-Omacase files and unrelated Homebrew packages.
- Use `omacase backup` before a manual cutover.
- Accessibility and Automation grants require user action.

## Troubleshooting

- Popup/overlay helper does not center: verify the terminal has Accessibility.
- Change installed applications: edit `Brewfile`, then run `omacase install`.
- Change a managed dotfile or theme renderer: edit the repository source and
  run the proportional tests in `tests/run.sh`.
