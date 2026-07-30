# shellcheck shell=bash
# `omacase keybinds` — display the project key reference. Render Markdown in an
# interactive terminal when glow is available; emit the source unchanged when
# redirected so it remains searchable, pipeable, and testable.

omacase_keybinds() {
  [ $# -eq 0 ] || abort "usage: omacase keybinds"
  local reference="$OMACASE_ROOT/KEYBINDS.md"
  [ -f "$reference" ] || abort "Key reference missing: $reference"

  if [ -t 1 ] && have glow; then
    glow -s "$HOME/.config/glow/omacase-glow.json" "$reference" && return
  fi
  command cat "$reference"
}
