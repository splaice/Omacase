# Omacase key reference

Omacase uses OmniWM's native Option-based shortcuts.

## Window management

| Keys | Action | Layout |
|---|---|---|
| `⌥ + Arrow` | Focus left/right/up/down | Shared |
| `⌥⇧ + Arrow` | Move the focused window | Shared |
| `⌥ + 1…9` | Switch to workspace | Shared |
| `⌥⇧ + 1…9` | Move focused window to workspace | Shared |
| `⌃⌥ + Tab` | Previous workspace, back and forth | Shared |
| `⌥ + Return` | Toggle fullscreen | Shared |
| `⌥ + .` / `⌥ + ,` | Cycle size forward/back | Shared |
| `⌥⇧ + B` | Balance sizes | Shared |
| `⌥⇧ + L` | Toggle Niri/Dwindle layout | Shared |
| `⌃⌥⇧ + Left/Right` | Move the whole container | Shared |
| `⌥ + T` | Toggle tabbed column | Niri |
| `⌥⇧ + F` | Toggle full primary span | Niri |

In Dwindle, `⌥⇧ + Arrow` is contextual: a singleton joins the neighboring tile;
an active grouped tab is extracted in the requested direction. OmniWM's
Settings → Hotkeys screen is authoritative and supports changing every binding.

## OmniWM surfaces

| Keys | Action |
|---|---|
| ``⌥ + ` `` | Toggle quake terminal |
| `⌥⇧ + O` | Toggle overview |
| `⌃⌥ + Space` | Toggle command palette |
| `⌃⌥ + M` | Open the OmniWM menu anywhere |

## macOS

| Keys | Action |
|---|---|
| `⌘ Space` | Spotlight |
| `⌘ Tab` | macOS app switcher |
| `⌃⌘ Space` | Emoji & Symbols |

Spotlight is the launcher, unmodified. Omacase adds no launcher applications of
its own; run `omacase menu` for its TUI, or bind any `omacase` subcommand as an
OmniWM shortcut.

## Terminal

Ghostty, shell, and editor bindings remain independent of OmniWM. Use
`omacase terminal` when a script needs a new Ghostty window and
`omacase files` for the optional ranger popup.
