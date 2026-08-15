# shellcheck shell=bash
# Omacase no longer generates Spotlight launcher .app bundles, and `omacase
# sysmenu` — the floating menu popup one of them opened — is gone with them.
# The code that knew how to delete these bundles was removed in the same change,
# so this migration carries its own copy of that logic.
#
# SCOPE / SAFETY: only bundles carrying the marker file Omacase wrote into every
# launcher it built (Contents/Resources/.omacase-launcher) are removed. An
# unrelated .app in ~/Applications is never touched, whatever it is named.
#
# `omacase webapp` and `omacase appearance` are unaffected — they remain CLI and
# `omacase menu` commands — so Brave is still the chromeless web-app browser and
# stays in the Brewfile.
migrate() {
  local dir="$HOME/Applications" app n=0
  [ -d "$dir" ] || return 0
  for app in "$dir"/*.app; do
    [ -e "$app/Contents/Resources/.omacase-launcher" ] || continue
    if run rm -rf "$app"; then
      n=$((n + 1))
    else
      warn "migrate: couldn't remove '$app' (skipped)."
    fi
  done
  if [ "$n" -gt 0 ]; then
    info "Removed $n generated Spotlight launcher(s) from $dir."
  fi
  return 0
}
