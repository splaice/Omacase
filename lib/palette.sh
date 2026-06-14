# shellcheck shell=bash
# `omacase palette [theme]` — interactive TUI to edit a theme's Ghostty ANSI
# palette with a live, truecolor `ls`/eza preview, so you can dial in the slot
# colors WITHOUT reloading Ghostty repeatedly. The actual editor is lib/palette.py.

omacase_palette() {
  local theme="${1:-}"
  [ -n "$theme" ] || theme="$(cat "$OMACASE_STATE/theme" 2>/dev/null || echo)"
  [ -n "$theme" ] || abort "no theme given and no active theme — usage: omacase palette [name]"

  local f="$OMACASE_ROOT/themes/$theme/ghostty"
  [ -f "$f" ] || abort "unknown theme '$theme' (themes/$theme/ghostty not found)."

  # Only inline-palette themes are editable slot-by-slot. The few that just
  # select a Ghostty built-in (e.g. catppuccin-mocha, tokyo-night) have no
  # palette lines to tweak.
  if ! grep -q '^palette = 0=' "$f"; then
    abort "theme '$theme' uses a Ghostty built-in (\`$(grep -i '^theme' "$f" | head -1 | sed 's/theme *= *//')\`), so it has no inline palette to edit."
  fi

  have python3 || abort "python3 is required for \`omacase palette\` (install Xcode CLT or \`brew install python\`)."

  OMACASE_STATE="$OMACASE_STATE" python3 "$OMACASE_ROOT/lib/palette.py" "$f" "$theme"

  # After editing, nudge the user toward applying if they edited a non-active
  # theme (the in-TUI `a` only reloads Ghostty for the active theme).
  local active; active="$(cat "$OMACASE_STATE/theme" 2>/dev/null || echo)"
  if [ "$theme" != "$active" ]; then
    info "Edited '$theme'. Run \`omacase theme $theme\` to switch to it and see the result."
  fi
}
