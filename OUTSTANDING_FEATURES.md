# Outstanding Features

The Omacase ↔ Omarchy **parity record**: what we've built and what we've decided
against, from a gap analysis (Omacase repo vs. the Omarchy manual /
`basecamp/omarchy`, stable v3.8.2 ≈ dev 4.0.0-alpha).

> **Planned / forward-looking work now lives in [`FUTURE.md`](FUTURE.md).** This
> file keeps the **completed** items (a record of the parity work) and the
> explicit **out-of-scope** decisions (so we don't relitigate them).

---

## Tier 1 — High value, low effort

- [x] **Bar: system-status modules** — CPU + memory on SketchyBar, click → btop. ✅
  - Scope decision: macOS's own menu bar owns battery/network/bluetooth/audio, so the bottom bar only adds what it lacks: **live CPU + memory** (`sysstats.sh`, left, next to caffeine, updates every 5s).
  - Click **toggles** a **controlled btop window** via the `omacase btop` subcommand (`lib/wm.sh`): a new window in the *existing* (undecorated) Ghostty instance — not a 2nd instance (avoids the session-restore prompt) — running `exec btop` (so quitting btop closes the window), floated via `aerospace layout floating`, centered at ~65% of the main display via System Events. Clicking again sends `q` and the window closes.
  - Files: `lib/wm.sh` (`omacase_btop`), `bin/omacase` + `completions/_omacase` (dispatch/usage), `home/dot_config/sketchybar/sketchybarrc` (`sysstats.sh` + click → `omacase btop`).

- [x] **App-launch keybind layer** — bare-Super launch/overlay binds. ✅
  - `Super+B` → default browser (`omacase browser`, reads the LaunchServices https handler).
  - `Super+Shift+F` → ranger file popup (`omacase files`; `Super+F` is fullscreen). Chromeless centered Ghostty, toggle. Added `ranger` to the Brewfile.
  - `Super+M` → music overlay (`omacase music`; default Spotify, `omacase music apple` switches to Apple Music, falls back to whichever is installed).
  - `Super+O` → Obsidian overlay (`omacase obsidian`).
  - `Super+P` → 1Password overlay (`omacase 1password`).
  - Overlay pattern: GUI apps (music/obsidian) toggle reveal/hide as centered floats *above* everything (`_app_toggle` + `on-window-detected` float rules); terminal popups (btop/files) share `_ghostty_popup_toggle`.
  - Files: `lib/wm.sh`, `bin/omacase`, `completions/_omacase`, `home/dot_config/aerospace/aerospace.toml`, `Brewfile`, `KEYBINDS.md`.

- [x] **Default messaging app** — `Super+G` → iMessage. ✅
  - `omacase message` (alias `messages`) toggles a centered Messages overlay sized to 80% of the screen (chat wants more room than the other overlays — `_app_toggle` gained an optional size-percent arg). Single default for now; multiple-app support (Signal/etc., like `omacase music`) can come later.

- [x] **Per-app window rules** — curated float list for system utilities. ✅
  - A grouped, commented "Window rules" section in `aerospace.toml` floats ~30 system-utility / dialog-style apps (Calculator, Activity Monitor, System Settings, Disk Utility, Font Book, Screenshot, Console, …), the input/WM helper settings (Karabiner, BetterMouse, Loop), and small converters — so they escape tiling. Everything else tiles (the correct default); extend by copy-pasting a block (the header documents how + the float/tile-only caveat).
  - Kept native/inline (chosen over a generated registry): AeroSpace is single-file with no includes, the exception set is small, and a plain block is the copy-pasteable path for others.
  - Note: `on-window-detected` can't size/position — only float/tile/assign-workspace. Centered/sized overlays stay the job of the `omacase` commands.
  - Deferred: workspace pinning (`move-node-to-workspace`) — opinionated, interacts with dynamic workspaces.
  - Files: `home/dot_config/aerospace/aerospace.toml`.

- [x] **Bar: update-available indicator** — Homebrew outdated count on the left. ✅
  - Logic lives in `omacase outdated` (lib/update.sh): counts `brew outdated` and paints the SketchyBar `update` item; shown only when >0, hidden otherwise. Polled every 30 min + on wake. Click → `omacase update` in a terminal.
  - Gotcha handled: brew crashes when the SketchyBar daemon spawns it directly (`Hardware::CPU.cores` → nil), so `omacase outdated` runs brew inside a fresh login shell; `HOMEBREW_NO_AUTO_UPDATE=1` keeps it read-only/fast.
  - Future: fold in omacase self-updates once omacase ships versioned releases (no distribution yet).
  - Files: `lib/update.sh`, `bin/omacase`, `completions/_omacase`, `home/dot_config/sketchybar/sketchybarrc`.

---

## Tier 2 — Medium value

- [x] **Global system menu** — `Super + Space` → `omacase sysmenu` opens the gum TUI
  as a centered, floating Ghostty popup (same `_ghostty_popup_toggle` mechanic as btop/files).
  Mirrors Omarchy's `SUPER+ALT+SPACE` (on macOS the Alt is already inside Super=⌃⌥⌘).
  (Extending the gum-menu *content* — Capture/Toggle/power entries — is planned in `FUTURE.md`.)
  - Files: `lib/wm.sh` (`omacase_sysmenu`), `lib/menu.sh`, `home/dot_config/aerospace/aerospace.toml`.

- [x] **Config migrations** — `omacase migrate` (`lib/migrate.sh`), run by `omacase update`.
  Timestamp-ordered idempotent scripts in `migrations/`; high-water mark in
  `$OMACASE_STATE/migrations-last`. **Surgical scope:** only removes Omacase-managed
  drops by exact name (never `brew bundle cleanup`), so a user's own Homebrew
  packages are untouched. Seeded with `20260613-remove-dropped-apps` (Ice/Zed/
  yabai/skhd + the koekeishiya tap).
  - To add one: drop `migrations/<YYYYMMDD-slug>.sh` defining an idempotent `migrate()`.

> Remaining Tier-2/Tier-3 ideas (wallpaper cycling, gum-menu content, theme-from-URL,
> font switcher, color-picker / OCR / reminders / Night-Shift hotkeys, an Omacase
> bundle id) moved to [`FUTURE.md`](FUTURE.md).

---

## Out of scope (recorded so we don't relitigate)

**Native on macOS — no gap:** screenshots/recording (`⌘⇧3/4/5`), lock screen
(`⌃⌘Q`), idle/screensaver, volume/brightness/media-key OSD, wifi/bluetooth menus,
clipboard history (Tahoe Spotlight). Clock was removed on purpose.

**DND / Focus toggle — won't implement; defer to macOS.** macOS owns Focus
(Control Center / Focus modes) with a strong, locked-down implementation and no
stable public toggle. We won't fight it with brittle UI-scripting or DoNotDisturb
DB pokes — use the native Focus controls. (Only the notify *helper* half of the
original item shipped: `omacase notify`.)

**Linux-only / impractical:** ISO installer, Limine/Plymouth/SDDM, btrfs+Snapper
boot rollback, hardware tuning, gaming stack, Windows VM, UFW/FIDO2, keyboard RGB,
Hyprland blur/shadows, window **grouping/tabbed** & **scratchpad** (AeroSpace
limitation), Caps→Compose key.

**Already in Omacase:** caffeinate toggle, gaps, accordion, 2×2 grid (`Super+q`),
global system menu (`Super+Space`), native notifications (`omacase notify` +
terminal-notifier), web apps + Spotlight launchers, dictation (Wispr Flow),
modern CLI stack (eza/bat/fd/rg/fzf/zoxide/atuin/mise/direnv).
