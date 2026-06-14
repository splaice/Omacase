# Omacase — Future Additions

The consolidated, forward-looking list of planned work for Omacase. Completed
features are documented in the [`README.md`](README.md); the explicit non-goals
are in the README's *"What Omacase leaves to macOS (by design)"* section. This
file is only what's *planned*.

Everything here follows house style: subcommands in `lib/*.sh`, helpers from
`lib/common.sh` (`run`/`have`/`info`/`success`/`warn`/`OMACASE_STATE`), idempotent
install steps, a `doctor` section, completion entries kept in sync, bash-3.2-safe.

---

## 1. Local LLM — a default on-device model  *(largest planned feature)*

Ship Omacase with a **default local model** that augments Claude: a fast,
always-available **OpenAI-compatible endpoint on `localhost`** for document
analysis (LLM wikis, RAG over notes), light coding, and quick chat — without a
round-trip to a hosted model. (Consolidated from the former `LOCALLLM_PLAN.md`.)

### Model ladder
MoE wins on Apple Silicon — inference is memory-bandwidth-bound, and a sparse MoE
only reads its *active* params per token, so it runs at small-model speed with
mid-model quality.

| Tier | Model | Format | On disk | ~Speed (M4 Max) | Role |
|---|---|---|---|---|---|
| **Default** (64 GB floor) | `Qwen3-30B-A3B-Instruct` (2507) | MLX 4-bit | ~18 GB | 45–70 tok/s | shipped default |
| Lighter alt | `gpt-oss-20b` | MLX MXFP4 | ~13 GB | 60–90 tok/s | low-RAM / max-speed |
| **Big option** (≥96–128 GB) | `gpt-oss-120b` | MLX MXFP4 | ~63 GB | 40–60 tok/s | opt-in, RAM-gated |

Default = `Qwen3-30B-A3B-Instruct`: 256K native context (whole wikis / multiple
docs), ~3B active params so it stays interactive, ~18 GB leaves 25–30 GB on a
64 GB box for KV cache + apps. Use the **Instruct (non-thinking)** variant.

> Model IDs are **config values, not hardcodes** — the local-MoE space turns over
> every few months. `~/.config/omacase/llm.conf` rerolls the default without a
> code change.

### Architecture
- **Engine:** `mlx-lm` (fastest tok/s on Apple Silicon), installed via
  `uv tool install mlx-lm` (isolated; no global Python mess). `uv` is the one new dep.
- **Server:** `mlx_lm.server` — OpenAI-compatible (`/v1/chat/completions`) on
  `127.0.0.1:8080`. Anything that speaks the OpenAI API points at it.
- **Supervision:** a per-user **LaunchAgent** (`com.omacase.llm.plist`, an Omacase
  dotfile symlink) so the endpoint is always up and restarts on login/crash;
  `launchctl` driven from `lib/llm.sh`. The plist stays static and reads the
  configured model/port via thin `omacase llm … --print` accessors.
- **Weights:** pulled on demand into the HF cache (`~/.cache/huggingface`).

File map:
```
bin/omacase                                       # + `llm` dispatch case
lib/llm.sh                                         # new: omacase_llm() + helpers
lib/common.sh                                      # + system_ram_gb(), llm_usable_vram_gb()
lib/install.sh                                     # + optional RAM-gated "Local LLM" step
lib/doctor.sh                                      # + "Local LLM" diagnostic section
Brewfile                                           # + uv
completions/_omacase                               # + `llm` subcommands
home/Library/LaunchAgents/com.omacase.llm.plist    # dotfile: the supervised server
~/.config/omacase/llm.conf                         # user config: model id, tier, port, wired-limit opt-in
~/.local/state/omacase/llm/                        # runtime: pid, skip marker, logs
```

### `omacase llm` command surface
| Command | Action |
|---|---|
| `omacase llm` / `status` | engine, chosen model, server up/down, port, RAM headroom |
| `omacase llm start` / `stop` / `restart` | `launchctl` the LaunchAgent |
| `omacase llm model [name]` | no name → list + show current; with name (`default`/`lite`/`big`/id) → set in `llm.conf` + restart |
| `omacase llm pull [name]` | pre-download weights (default = configured model) |
| `omacase llm chat [prompt]` | one-shot curl/REPL against the local endpoint (smoke test) |
| `omacase llm tune` | apply the GPU wired-memory limit for big-context / big-model runs |

### GPU wired-memory tuning — `omacase llm tune`
On 64 GB, macOS gives the GPU ~70–75% of unified RAM; a long (256K) KV cache can
starve. `tune` raises `iogpu.wired_limit_mb` (leave ~16 GB for macOS+apps) so
big-context runs don't spill. **Opt-in, never silent:** needs sudo, follows the
`confirm`-before-mutate pattern, not persistent across reboot unless the user
opts into a LaunchDaemon. Shared helpers in `lib/common.sh`:
`system_ram_gb()`, `llm_usable_vram_gb()` (~72% of total).

### Install & doctor integration
- **Install:** a new **optional, RAM-gated** step in `omacase_install` (opt-in —
  pulls ~18 GB). `<60 GB` → offer **lite** (gpt-oss-20b); `≥96 GB` → recommend
  **default**, mention **big**; else → **default**. Skips record a marker and tell
  the user to resume with `omacase llm start`. Idempotent on re-run (engine no-op
  if present, `hf download` no-ops if cached, `launchctl bootstrap` tolerant).
- **Doctor:** a "Local LLM" section — engine present, LaunchAgent linked, server
  up, RAM headroom; counts `issues` and deep-links the fix like the others.
- **Brewfile:** add `uv`. **Completions:** add `llm` subcommands + `default|lite|big`.

### Open decisions (need a call before building)
1. **Runtime:** `mlx-lm` + LaunchAgent (recommended — lean/scriptable/fastest) vs.
   **LM Studio** cask (GUI: model browser/chat). Plan defaults to mlx-lm; LM Studio
   could be a documented alternate profile later.
2. **Always-on vs. on-demand:** ship enabled at login (KeepAlive) vs. start-on-use.
   Plan = always-on, but install asks; low-RAM machines should default to on-demand.
3. **Default model pinning:** verify the current best 4-bit/MXFP4 MLX-community
   uploads at build time (these re-upload).
4. **Big-tier gate:** mention `gpt-oss-120b` at ≥96 GB, never auto-pull.

### Build checklist
- [x] Brewfile: add `uv` (done — `uv` is now a declared Omacase package)
- [ ] `lib/llm.sh`: `omacase_llm` + helpers, `omacase_llm_tune`
- [ ] `lib/common.sh`: `system_ram_gb`, `llm_usable_vram_gb`
- [ ] `bin/omacase`: `llm)` dispatch + usage line
- [ ] `home/Library/LaunchAgents/com.omacase.llm.plist`
- [ ] `lib/install.sh`: `_llm_offer_install` step (RAM-gated, opt-in) + renumber banners
- [ ] `lib/doctor.sh`: Local LLM section
- [ ] `completions/_omacase`: `llm` subcommands + model aliases
- [ ] `README.md`: "Local model" section
- [ ] Test matrix: 64 GB (default), 128 GB (big), <60 GB (lite/skip), dry-run, re-run idempotency
- [ ] If we lock in mlx-lm + LaunchAgent over LM Studio, record it as a `project` memory

---

## 2. Themes & desktop

- **Wallpaper cycling** — multiple backgrounds per theme + a cycle hotkey.
  - Omarchy: per-theme `backgrounds/` dir, `omarchy-theme-bg-next`.
  - macOS: extend the `omacase theme` wallpaper step (already supports a single
    bundled `themes/<name>/background.*`) to multiple images; add `omacase
    wallpaper next` + a keybind. Reuse the mtime-staged `.live` cache-bust.
  - Files: `lib/theme.sh`, `themes/*/`.
- **Theme install from URL** — `omacase theme install <git-url>` (clone a
  community theme into `themes/`, like Omarchy's menu-paste install).
- **Font switcher** — `omacase font <name>` to retarget Ghostty + SketchyBar.

## 3. Menu & system

- **System-menu content** — extend the gum menu (`omacase sysmenu` / `omacase
  menu`) with **Capture / Toggle / power** entries for fuller Omarchy parity. The
  launcher already shipped on `Super+Space`; this is the menu *content*.
  - Files: `lib/menu.sh`.
- **Own Omacase bundle ID + notification identity** — ship a minimal signed `.app`
  (e.g. `app.omacase` / `com.omacase.Omacase`) so notifications are attributed to
  "Omacase" with our own left icon, instead of borrowing terminal-notifier's
  identity or riding `-contentImage`.
  - Why: macOS pins a banner's left icon to the *sending* bundle; only a real
    bundle (or `terminal-notifier -sender <our-id>`) gets the true Omacase icon.
  - Sketch: tiny notifier `.app` (icon = `assets/omacase-icon.png`), code-signed,
    then `terminal-notifier -sender app.omacase`. Pick the canonical bundle id
    once and reuse it for future launchers/Shortcuts.
  - Files: `lib/notify.sh`, new `app/` (or `macos/`) bundle, install step.

## 4. Hotkeys

- **Color-picker hotkey** — Digital Color Meter or a CLI picker on a key.
- **Screen OCR hotkey** — macOS Live Text / `shortcuts` to grab text from a region.
- **Quick reminders hotkey** — set/show via Reminders/osascript (`omarchy-reminder` analog).
- **Night Shift toggle hotkey** — toggle macOS Night Shift on a key.

---

## Not planned (recorded so we don't relitigate)

See the README's [*"What Omacase leaves to macOS (by design)"*](README.md#what-omacase-leaves-to-macos-by-design)
section: the **DND / Focus toggle** (defer to macOS), things already native on
macOS (screenshots, lock, clipboard history, …), and Linux-only items.
