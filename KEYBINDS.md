# Omacase Keybinds

Two separate layers:

- **Alt** = window management (AeroSpace tiling)
- **Launcher** = **Spotlight** (`⌘Space`) — built in; nothing to configure
- **Super** = **right ⌘** (a Hyper key via Karabiner) = free for your own Shortcuts

Reload the WM config after edits: **`Alt + Shift + c`**.

---

## Launcher — Spotlight (built in)
On Tahoe, Spotlight is launcher + Actions + clipboard history + Quick Keys.

| Keys | Action |
|---|---|
| `⌘ Space` | Spotlight — launcher / search / Actions / clipboard history |
| `⌃⌘ Space` | Emoji & Symbols (Character Viewer) |
| `⌘ Tab` / AltTab | Switch windows |

> No setup — `⌘Space` is Spotlight by default. If it's been reassigned, re-enable it
> in System Settings → Keyboard → Keyboard Shortcuts → Spotlight.
>
> **Super** (right ⌘ = ⌘⌃⌥⇧ via Karabiner) is unbound by default now — point it at
> your own **Shortcuts** to trigger automations from anywhere.

---

## Alt — AeroSpace window management

### Focus / move
| Keys | Action |
|---|---|
| `Alt + h / j / k / l` | Focus left / down / up / right |
| `Alt + Shift + h / j / k / l` | Move window left / down / up / right |

### Size & layout
| Keys | Action |
|---|---|
| `Alt + f` | **Fullscreen toggle** (fills the screen; yields when another window takes the space) |
| `Alt + =` | Grow focused window |
| `Alt + -` | Shrink focused window |
| `Alt + e` | Tiles layout — flip split orientation (side-by-side ↔ stacked) |
| `Alt + w` | Accordion layout — windows stack, focused one expands |
| `Alt + Shift + Space` | Float / unfloat the window (escape tiling) |

### Workspaces (the way to give each app a full screen)
| Keys | Action |
|---|---|
| `Alt + 1 … 9` | Switch to workspace N |
| `Alt + Shift + 1 … 9` | Send focused window to workspace N |
| `Alt + Tab` | Toggle to previous workspace |
| `Alt + Shift + Tab` | Move workspace to the next monitor |

### Service mode — `Alt + Shift + ;`, then:
| Key | Action |
|---|---|
| `esc` | Reload config and exit service mode |
| `r` | Flatten / reset the workspace tree (fixes weird splits) |
| `f` | Toggle floating/tiling for the window |
| `backspace` | Close all windows but the focused one |

---

## Why windows "keep shrinking"
AeroSpace tiles **every** window in a workspace, so each new window you open in
that space shrinks the others to make room. `Alt + f` fullscreen is a per-window
*toggle* — it does **not** stop new/!other windows from re-tiling the space, so it
looks like things "un-fullscreen."

The fix is to give busy apps their own space instead of cramming one workspace:

- Put one app per workspace: focus it, `Alt + Shift + 2` to send it to space 2,
  then `Alt + 1` / `Alt + 2` to flip. A workspace with a single window is
  effectively full-screen and stays that way.
- Or use `Alt + w` (accordion) so the focused window stays large and the rest
  tuck to the side.
- Use `Alt + f` for a quick temporary zoom, not as a permanent state.
