---
name: omacase
description: Install, update, theme, back up, and diagnose an opinionated OmniWM-based macOS environment with the omacase CLI.
---

# Omacase

Use the current checkout's `bin/omacase` (or `omacase` when linked) for changes
to the Omacase-managed Mac environment.

## Main operations

- `omacase install` — idempotently apply packages, dotfiles, defaults, theme,
  OmniWM first-run seed, login launch, and Spotlight helpers.
- `omacase update` — pull, reapply, migrate, and update packages/tools.
- `omacase doctor` — inspect OmniWM, its IPC, separate Spaces, permissions,
  command links, backups, and macOS window-management settings.
- `omacase wm` — seed only a missing OmniWM config, register login launch, and
  start/verify OmniWM.
- `omacase keybinds` — render the project key reference in the terminal.
- `omacase theme [name]`, `palette [name]`, `wallpaper [...]` — visual system.
- `omacase backup [label]`, `restore [id]` — reversible configuration snapshots.
- `omacase migrate` — apply exact, tracked one-time cleanups.

## Ownership

Omacase owns files linked from `home/`, its generated theme cache, package
declarations, macOS defaults, and its login agent. It copies
`config/omniwm/settings.toml` to `~/.config/omniwm/settings.toml` only when the
live file does not exist. Do not replace or symlink the live OmniWM settings:
OmniWM and the user own it after seeding.

OmniWM owns window layouts, workspaces, rules, borders, workspace bar, overview,
quake terminal, and hotkeys. Assume its default Option-based shortcuts unless
the live settings show otherwise.

## Safety

- Preview broad changes with `OMACASE_DRYRUN=1 omacase install`.
- Preserve non-Omacase files and unrelated Homebrew packages.
- Use `omacase backup` before a manual cutover.
- Accessibility and Automation grants require user action.
- Enabling separate Spaces requires a logout before OmniWM can manage multiple
  displays correctly.

## Troubleshooting

- Tiling unavailable: run `omacase doctor`, verify Accessibility, separate
  Spaces, and that Stage Manager is disabled, then `omacase wm`.
- Popup helper does not float: verify OmniWM IPC is enabled.
- Change a shortcut or layout: use OmniWM Settings; the live file is user-owned.
- Change installed applications: edit `Brewfile`, then run `omacase install`.
- Change a managed dotfile or theme renderer: edit the repository source and
  run the proportional tests in `tests/run.sh`.
