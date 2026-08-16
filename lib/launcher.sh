# shellcheck shell=bash
# OmacaseLauncher — a real app bundle (~/Applications/OmacaseLauncher.app) that
# performs Omacase's login-time launches, driven by ~/.config/omacase/
# login-items. A LaunchAgent (org.omacase.launcher) runs the bundle's binary
# directly, so System Settings → Login Items attributes the row to
# "OmacaseLauncher" — not "open", which is what the old raw-agent approach
# displayed. The agent plist is GENERATED (it embeds $HOME paths), unlike the
# symlinked assets; uninstall removes it by its org.omacase.* name.

_LAUNCHER_APP="$HOME/Applications/OmacaseLauncher.app"
_LAUNCHER_AGENT="$HOME/Library/LaunchAgents/org.omacase.launcher.plist"
_LAUNCHER_LABEL="org.omacase.launcher"

# Build/refresh the bundle and the agent plist (files only — no launchctl), so
# tests can exercise it against a scratch $HOME. Generated content is staged in
# a temp dir and moved into place with `run`, keeping dry-run faithful.
_launcher_build() {
  local macos="$_LAUNCHER_APP/Contents/MacOS"
  local res="$_LAUNCHER_APP/Contents/Resources"
  local stage
  stage="$(mktemp -d)"
  run mkdir -p "$macos" "$res" "$(dirname "$_LAUNCHER_AGENT")"
  run install -m 0755 "$OMACASE_ROOT/assets/launcher/OmacaseLauncher.sh" "$macos/OmacaseLauncher"
  run cp "$OMACASE_ROOT/assets/launcher/Info.plist" "$_LAUNCHER_APP/Contents/Info.plist"
  _launcher_icon "$stage"

  cat > "$stage/agent.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$_LAUNCHER_LABEL</string>
  <key>AssociatedBundleIdentifiers</key>
  <array>
    <string>org.omacase.launcher</string>
  </array>
  <key>ProgramArguments</key>
  <array>
    <string>$macos/OmacaseLauncher</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF
  run cp "$stage/agent.plist" "$_LAUNCHER_AGENT"

  if have codesign; then
    run codesign -s - -f "$_LAUNCHER_APP" 2>/dev/null || true
  fi
  rm -rf "$stage"
}

# Best-effort .icns from the Omacase PNG so the Login Items row gets an icon.
_launcher_icon() {
  local stage="$1"
  local png="$OMACASE_ROOT/assets/omacase-icon.png"
  local iconset="$stage/AppIcon.iconset"
  { [ -f "$png" ] && have sips && have iconutil; } || return 0
  {
    mkdir -p "$iconset" &&
    sips -z 128 128 "$png" --out "$iconset/icon_128x128.png" >/dev/null 2>&1 &&
    sips -z 256 256 "$png" --out "$iconset/icon_256x256.png" >/dev/null 2>&1 &&
    iconutil -c icns "$iconset" -o "$stage/AppIcon.icns" >/dev/null 2>&1 &&
    run cp "$stage/AppIcon.icns" "$_LAUNCHER_APP/Contents/Resources/AppIcon.icns"
  } || true
}

_launcher_install() {
  _launcher_build
  local domain
  domain="gui/$(id -u)"
  if is_dryrun; then
    run launchctl bootstrap "$domain" "$_LAUNCHER_AGENT"
  else
    launchctl bootout "$domain/$_LAUNCHER_LABEL" >/dev/null 2>&1 || true
    launchctl bootstrap "$domain" "$_LAUNCHER_AGENT" >/dev/null 2>&1 || \
      warn "Could not register OmacaseLauncher at login; add it in System Settings → General → Login Items."
  fi
}

_launcher_uninstall() {
  run launchctl bootout "gui/$(id -u)/$_LAUNCHER_LABEL" 2>/dev/null || true
  run rm -f "$_LAUNCHER_AGENT"
  run rm -rf "$_LAUNCHER_APP"
}
