# shellcheck shell=bash
# The Starship prompt is now inverted (colored blocks, background-colored text).
# Local themes carry it in-tree; Omarchy-derived themes are cached generated
# output under $OMACASE_DATA (Omacase-owned), so patch those in place.
# Idempotent: only style lines not already inverted are touched.
migrate() {
  local f
  for f in "$OMACASE_DATA"/generated/themes/*/starship; do
    [ -f "$f" ] || continue
    run sed -i '' -E \
      -e "/inverted/!s/^style = '([^']+)'\$/style = '\\1 inverted'/" \
      -e "/inverted/!s/^((success|error)_symbol = '\\[[^]]+\\]\\()([^)]+)\\)'\$/\\1\\3 inverted)'/" \
      "$f"
  done
  return 0
}
