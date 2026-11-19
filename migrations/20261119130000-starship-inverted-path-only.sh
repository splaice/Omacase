# shellcheck shell=bash
# The inverted prompt is now path-only: [directory] keeps `inverted`, every
# other style drops it. Patch the Omacase-owned cached Omarchy-derived themes
# under $OMACASE_DATA (materialize reuses them). Idempotent.
migrate() {
  local f
  for f in "$OMACASE_DATA"/generated/themes/*/starship; do
    [ -f "$f" ] || continue
    if is_dryrun; then log "[dry-run] would make the prompt path-only inverted in $f"; continue; fi
    awk '/^\[/{sec=$0} { if (sec!="[directory]") sub(/ inverted/, ""); print }' "$f" > "$f.tmp"
    mv "$f.tmp" "$f"
  done
  return 0
}
