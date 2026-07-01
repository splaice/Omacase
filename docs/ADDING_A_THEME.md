# Adding a theme

Themes are catalogued in `themes/manifest`, one pipe-delimited row per theme:

```
# name|title|source|upstream|nvim
techno-viking|Techno Viking|local|-|techno-viking
gruvbox|Gruvbox|omarchy|gruvbox|gruvbox
```

- **name** — the CLI id (`omacase theme <name>`); one word, kebab-case.
- **title** — human-readable, used in generated fragment headers.
- **source** — `local` (fragments vendored in this repo) or `omarchy`
  (rendered at runtime from Basecamp's Omarchy `colors.toml`).
- **upstream** — the Omarchy theme directory name; `-` for local themes.
- **nvim** — the Neovim colorscheme name `lua/theme.lua` returns.

Rows with fewer than 5 fields are ignored everywhere (picker, `_theme_known`).

## Omarchy-derived theme

Add the manifest row — that's it. `omacase theme <name>` downloads
`themes/<upstream>/colors.toml` from the Omarchy repo, caches it under
`~/.local/share/omacase/upstream/`, and renders the six app fragments into
`~/.local/share/omacase/generated/themes/<name>/`. Wallpapers are fetched on
first use. Make sure the `nvim` column names a colorscheme LazyVim can load
(add a plugin spec to `home/dot_config/nvim/lua/plugins/colorscheme.lua` if it
isn't bundled already).

## Local theme

1. Add the manifest row with `source=local`, `upstream=-`.
2. Create `themes/<name>/` containing the six fragments `omacase theme` links
   (see `_theme_links` in `lib/theme.sh`):
   - `ghostty` — Ghostty color config (background/foreground/cursor + 16 palette slots)
   - `sketchybar` — exports `BAR_COLOR`, `LABEL_COLOR`, `ACCENT`, `MUTED`
   - `borders` — exports `ACTIVE_BORDER`, `INACTIVE_BORDER`
   - `btop` — a btop theme file
   - `starship` — a Starship config fragment
   - `nvim.lua` — returns the colorscheme name (string)
   plus at least one `background.jpg` (more backgrounds → `omacase wallpaper`
   cycles them). Keep JPEGs ≲1 MB (`magick in.jpg -strip -quality 78 out.jpg`).
3. If the colorscheme is custom, ship it as a local plugin like
   `home/dot_config/nvim/techno-viking.nvim/` and register it in
   `home/dot_config/nvim/lua/plugins/colorscheme.lua`.

## Checks

- `bash tests/run.sh` — the suite derives the expected theme count from the
  manifest and verifies fragment rendering.
- Theme names Tab-complete automatically (`completions/_omacase` reads the
  manifest at completion time) — no completion edit needed.
- Optional: drop a desktop screenshot at `site/screenshots/themes/<name>.jpg`
  for the website gallery.
