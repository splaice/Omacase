---
name: macarchy
description: Install, configure, theme, and manage an opinionated tiling macOS (AeroSpace + SketchyBar + Ghostty + Raycast) via the `macarchy` CLI. Use when the user wants to set up their Mac, switch themes/window managers, diagnose tiling/permission issues, or change system defaults.
---

# macarchy — opinionated tiling macOS

macarchy is a single CLI (`~/.local/share/macarchy/bin/macarchy`) over an idempotent
bash engine. Prefer driving it through these subcommands instead of editing live
config by hand — the CLI keeps state and re-applies themes/WM consistently.

## Command surface
- `macarchy install` — full idempotent setup (re-runnable; same engine as update)
- `macarchy update` — git pull + `brew bundle` + re-apply dotfiles, defaults, theme, WM
- `macarchy theme [name]` — apply a theme everywhere at once (`catppuccin-mocha`, `tokyo-night`)
- `macarchy wm <aerospace|yabai>` — switch window-manager profile
- `macarchy doctor` — check tooling, WM, SIP state, and missing permission grants
- `macarchy menu` — gum TUI (bind to a Raycast hotkey)

## Architecture (where to change things)
- `Brewfile` — the package/app set; edit then `macarchy update`.
- `macos/defaults.sh` — `defaults write` layer (key repeat, Finder, Dock, screenshots…).
- `home/` — chezmoi source for dotfiles. `home/dot_config/aerospace/aerospace.toml`
  holds the Hyprland-style keybinds (Alt+hjkl focus, Alt+Shift+hjkl move, Alt+[1-9] workspaces).
- `themes/<name>/` — per-app color fragments; `macarchy theme` symlinks them into `~/.config`.
- `lib/*.sh` — one file per subcommand.

## Hard limits — set expectations honestly
- **Permission grants can't be automated.** AeroSpace/yabai, SketchyBar, Karabiner,
  and Raycast need Accessibility/Input-Monitoring approval that macOS (TCC) requires
  a human to click. `macarchy doctor` deep-links the right Settings pane; the user
  must toggle it.
- **yabai needs SIP partially disabled** — a manual Recovery-mode step that cannot be
  scripted from the running OS. Default to the **AeroSpace** profile, which needs none
  of this. Only walk the user through yabai if they explicitly want BSP dynamic tiling.
- **No blur / window animations / rounded corners on arbitrary windows** — macOS's
  window server doesn't expose them. JankyBorders (active-window borders) is the only
  Hyprland-style effect available. Don't promise the rest.

## Common requests → action
- "Set up my Mac" → `macarchy install`, then tell them to run `macarchy doctor` and grant permissions.
- "Change the theme" → `macarchy theme tokyo-night` (or list with `macarchy theme`).
- "Tiling stopped working" → `macarchy doctor`; check AeroSpace is running and granted Accessibility.
- "Add an app" → add a line to `Brewfile`, then `macarchy update`.
- "Tweak a keybind" → edit `home/dot_config/aerospace/aerospace.toml`, then `chezmoi apply` (or `macarchy update`).
