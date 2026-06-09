# Omacase

An opinionated, tiling macOS — installed, configured, themed, and managed from a
single command. Omarchy's ethos (keyboard-first, one consistent theme everywhere,
one-command reproducible) translated to where macOS actually wants to go.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/splaice/omacase/main/boot.sh)"
```

This installs Xcode CLT + Homebrew, clones to `~/.local/share/omacase`, and runs
`omacase install`. Then:

```bash
omacase doctor      # grant Accessibility to AeroSpace, SketchyBar, Karabiner
```

## The stack
| Layer | Pick |
|---|---|
| Window manager | **AeroSpace** (no SIP disable) — yabai available as advanced profile |
| Status bar | **SketchyBar** |
| Borders | **JankyBorders** |
| Launcher | **Spotlight** (built in — Tahoe actions, clipboard, Quick Keys) |
| Keyboard | **Karabiner-Elements** |
| Terminal | **Ghostty** + zsh/Starship + modern CLI set |
| Editor | **Neovim/LazyVim** + Zed |
| Packages | **Homebrew + Brewfile** |
| Dotfiles | **Omacase-owned symlinks** (`home/`) — won't collide with your own chezmoi/stow |
| Theme | **Catppuccin Mocha** (default) / Tokyo Night |

## Commands
```
OMACASE_DRYRUN=1 omacase install   # print every change without touching the system
omacase install            # idempotent full setup (re-runnable)
omacase update             # pull + brew bundle + re-apply everything
omacase theme [name]       # apply a theme everywhere at once
omacase wm aerospace|yabai # switch window-manager profile
omacase doctor             # check perms, SIP, missing grants
omacase backup [label]     # snapshot current dotfiles & macOS defaults
omacase restore [id]       # roll back to a snapshot (--list to see them)
omacase menu               # gum TUI (wrap in a Shortcut to launch from Spotlight)
```

> **Reversible by design.** `install` auto-snapshots any pre-existing dotfiles
> and the macOS defaults domains it touches *before* changing anything. Don't
> like the result? `omacase restore` puts your old setup back. Omacase manages
> its own dotfiles as symlinks, so it never fights an existing chezmoi/stow.

## Keybinds

Launcher — **Spotlight** (built in; no third-party launcher):
- `⌘ Space` — Spotlight: launcher / search / Actions / clipboard history (Tahoe)
- `⌃⌘ Space` — Emoji & Symbols (Character Viewer)
- `⌘ Tab` / AltTab — switch windows

> Nothing to configure — `⌘Space` is Spotlight by default. If a previous launcher
> took it, re-enable System Settings → Keyboard → Keyboard Shortcuts → Spotlight.

**Super** = **right ⌘**, remapped to a Hyper key (⌘⌃⌥⇧) by Karabiner
(`home/dot_config/karabiner/karabiner.json`). With no third-party launcher, Super
is yours to bind — point it at your own **Shortcuts** to run them from anywhere.

Alt — AeroSpace tiling (Hyprland-style):
- `Alt + h/j/k/l` — focus
- `Alt + Shift + h/j/k/l` — move window
- `Alt + [1-9]` — switch workspace · `Alt + Shift + [1-9]` — move window to workspace
- `Alt + f` — fullscreen · `Alt + Shift + Space` — toggle float · `Alt + Shift + c` — reload

## The two honest limits
1. **Permissions** (Accessibility/Input Monitoring) must be granted by hand — macOS
   requires it. `omacase doctor` links you straight there.
2. **yabai** needs SIP partially disabled (a manual Recovery step). The default
   **AeroSpace** profile needs none of that. Blur/window-animations are not possible
   on macOS regardless of WM — only borders.

## Managed by Claude
`skills/omacase/SKILL.md` teaches Claude to drive this CLI — so the same surface that
installs the system also lets an agent retheme, diagnose, and reconfigure it.

> Status: **0.1.0 scaffold** — the CLI engine, AeroSpace/SketchyBar/Ghostty/borders
> configs, Karabiner Super key, Neovim/LazyVim (theme-integrated), and both themes
> are real. Spotlight is the launcher (no setup — `⌘Space`); btop/starship theme
> fragments and the full Omarchy theme set ship too.
