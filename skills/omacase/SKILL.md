---
name: omacase
description: Install, configure, theme, and manage an opinionated tiling macOS (AeroSpace + SketchyBar + Ghostty + Spotlight) via the `omacase` CLI. Use when the user wants to set up their Mac, switch themes/window managers, diagnose tiling/permission issues, or change system defaults.
---

# Omacase — opinionated tiling macOS

Omacase is a single CLI (`~/.local/share/omacase/bin/omacase`) over an idempotent
bash engine. Prefer driving it through these subcommands instead of editing live
config by hand — the CLI keeps state and re-applies themes/WM consistently.

Supported target: Apple Silicon macOS with Homebrew at `/opt/homebrew`.

## Command surface

Setup & lifecycle:
- `omacase install` — full idempotent setup (re-runnable; same engine as update)
- `omacase update` — git pull + `brew bundle` + re-apply dotfiles, defaults, theme, WM, migrations (`OMACASE_SKIP_MISE_UPGRADE=1` skips npm-backed mise upgrades)
- `omacase migrate` — apply pending one-time migrations (also run by update)
- `omacase outdated` — count of outdated brew packages (drives the bar's update indicator)
- `omacase doctor` — check tooling, WM, and missing permission grants
- `omacase backup [label]` / `omacase restore [id]` — snapshot & roll back dotfiles + defaults
- `omacase uninstall` — remove omacase-managed symlinks & services (keeps apps)
- `omacase version` / `omacase help`

Theming:
- `omacase theme [name]` — apply a theme everywhere at once; theme names come from `themes/manifest` (run `omacase theme` to pick from the list). Omarchy-derived colors are downloaded from Basecamp's Omarchy repo into `~/.local/share/omacase/upstream/` and rendered into app fragments under `~/.local/share/omacase/generated/themes/`. Light/dark is derived from the theme background and also flips macOS appearance and the Claude Code CLI theme. The desktop wallpaper is fetched on first use into `~/.local/share/omacase/backgrounds/`, then cached.
- `omacase palette [name]` — TUI editor over a theme's Ghostty ANSI palette with a live truecolor eza preview
- `omacase wallpaper [list|next|prev|pick|<n>]` (alias `wp`) — choose among the active theme's backgrounds
- `omacase appearance [toggle|dark|light]` — flip/set macOS system Light/Dark

Window manager & desktop:
- `omacase wm` — (re)start the AeroSpace window manager + its shared services (SketchyBar, JankyBorders)
- `omacase grid [1-9]` — toggle a workspace into/out of a 2×2 grid (bound to Super+q)
- `omacase workspace <1-9>` (alias `ws`) — switch AeroSpace workspace
- `omacase terminal [cmd...]` (alias `term`) — new Ghostty window in the running instance, optionally running cmd
- Overlay toggles (centered floats above the tiles, each bound to a Super chord): `btop`, `files` (ranger), `browser`, `music [spotify|apple]`, `obsidian`, `1password` (alias `1pw`), `message` (alias `messages`), `todoist`, `sysmenu` (the Super+Space menu popup)
- `omacase webapp [name]` — open an Omarchy web app (no name = list); meant to be wrapped in a Spotlight Shortcut
- `omacase launchers [build|remove]` — generate/remove Spotlight `.app` launchers (in `~/Applications`) for web apps + workspaces + appearance toggle, via `osacompile`
- `omacase caffeinate [toggle|on|off|status]` (alias `caffeine`) — stay-awake power assertion (the bar's coffee cup)
- `omacase notify [--title|--subtitle|--sound|--image] <msg>` — native macOS notification for scripts/keybinds
- `omacase menu` — gum TUI (wrap in a Shortcut to launch from Spotlight); `omacase config` opens the config dir

**House rule — completion parity is a feature.** Any change to subcommands or
aliases MUST update `completions/_omacase` and `usage()` in `bin/omacase` in the
same commit.

## Reversibility (important)
- Omacase owns its dotfiles via **symlinks** from `home/` into `$HOME` — it does NOT
  use chezmoi, so it never collides with a user's existing chezmoi/stow setup.
- `install` calls `_auto_backup` first: it snapshots any pre-existing dotfile targets
  and the touched macOS `defaults` domains into `$OMACASE_STATE/backups/<id>/`.
- If a user dislikes the result, `omacase restore` rolls back (latest by default;
  `omacase restore --list` to choose). Don't hand-undo changes — use restore.

## Trust model
- The README install command is `curl | bash`; tell users to inspect `boot.sh`
  first if they do not already trust the repo.
- `brew bundle` uses curated third-party taps and a scoped Homebrew tap-trust
  bypass so install/update can run unattended.
- mise-managed npm tools track `latest`; use `OMACASE_SKIP_MISE_UPGRADE=1` when
  the user wants update without those npm upgrades.

## Architecture (where to change things)
- `Brewfile` — the package/app set; edit then `omacase update`.
- `macos/defaults.sh` — `defaults write` layer (key repeat, Finder, Dock, screenshots…).
  Keep `OMACASE_DEFAULTS_DOMAINS` in `lib/backup.sh` in sync with the domains it writes.
- `home/` — dotfile source (symlinked into `$HOME`; `dot_` prefix → `.`).
  `home/dot_config/aerospace/aerospace.toml` holds the Hyprland-style keybinds on
  the Super key (right ⌘ → ⌃⌥⌘ via Karabiner): Super+WASD focus, Super+Shift+WASD
  move, Super+[1-9] workspaces.
- `completions/_omacase` — zsh tab completion; keep in sync with every CLI change (see house rule above).
- `tests/run.sh` — pure-helper test suite; run it before committing `lib/` changes.
- `themes/manifest` — theme catalog and upstream/local source map.
- `themes/techno-viking*/` — local custom theme fragments and backgrounds.
- `~/.local/share/omacase/generated/themes/<name>/` — generated per-app fragments for Omarchy-derived themes; `omacase theme` symlinks these into `~/.config`.
- `lib/*.sh` — one file per subcommand.

## Hard limits — set expectations honestly
- **Permission grants can't be automated.** AeroSpace, SketchyBar, and
  Karabiner need Accessibility/Input-Monitoring approval that macOS (TCC) requires
  a human to click. `omacase doctor` deep-links the right Settings pane; the user
  must toggle it. The launcher is Spotlight (built in — no app or hotkey to set up).
- **No blur / window animations / rounded corners on arbitrary windows** — macOS's
  window server doesn't expose them. JankyBorders (active-window borders) is the only
  Hyprland-style effect available. Don't promise the rest.

## Common requests → action
- "Set up my Mac" → `omacase install`, then tell them to run `omacase doctor` and grant permissions.
- "Change the theme" → `omacase theme tokyo-night` (or list with `omacase theme`).
- "Tiling stopped working" → `omacase doctor`; check AeroSpace is running and granted Accessibility.
- "Add an app" → add a line to `Brewfile`, then `omacase update`.
- "Tweak a keybind" → edit `home/dot_config/aerospace/aerospace.toml` (it's symlinked, so changes are live; reload AeroSpace with Super+Shift+c).
- "Undo / I don't like this" → `omacase restore` (or `omacase restore --list` then `omacase restore <id>`).
