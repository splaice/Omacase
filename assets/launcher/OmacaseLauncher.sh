#!/bin/bash
# OmacaseLauncher — Omacase's login-time app starter. Installed as the
# executable of ~/Applications/OmacaseLauncher.app by `lib/launcher.sh` so
# System Settings → Login Items shows one honest "OmacaseLauncher" row instead
# of the bare "open" a raw LaunchAgent used to surface.
#
# Apps come from ~/.config/omacase/login-items (one `open -a` name per line,
# `#` comments); with no config it falls back to OmniWM. One bad entry must
# not stop the rest, so no `set -e` here.
set -u

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omacase/login-items"

apps=()
if [ -f "$CONFIG" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] && apps+=("$line")
  done < "$CONFIG"
else
  apps=(OmniWM)
fi

# ${apps[@]+…}: bash 3.2 treats expanding an empty array as unset under `set -u`.
for app in ${apps[@]+"${apps[@]}"}; do
  open -a "$app" || logger -t OmacaseLauncher "failed to open '$app'"
done
