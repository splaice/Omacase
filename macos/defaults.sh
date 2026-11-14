#!/bin/bash
# omacase macOS defaults — the `defaults write` layer (the .config analog).
# Idempotent: each key is set to a fixed value, so re-running is a no-op.
# Many changes need a relaunch of Dock/Finder/SystemUIServer (done at the end)
# or a full logout to fully apply.
set -euo pipefail

info() { printf '\033[34m➜\033[0m %s\n' "$*"; }
# Honor OMACASE_DRYRUN when invoked by `omacase install` (or standalone).
run() {
  if [ -n "${OMACASE_DRYRUN:-}" ]; then printf '\033[2m[dry-run]\033[0m %s\n' "$*"
  else "$@"; fi
}
[ -n "${OMACASE_DRYRUN:-}" ] && printf '\033[1;33m▒▒ DRY RUN — macOS defaults ▒▒\033[0m\n'

info "Keyboard: fast key repeat, disable press-and-hold (enables key-repeat in vim/etc.)"
run defaults write -g ApplePressAndHoldEnabled -bool false
run defaults write -g KeyRepeat -int 2
run defaults write -g InitialKeyRepeat -int 15

info "Finder: show extensions, path/status bar, POSIX path title, no .DS_Store on network"
run defaults write -g AppleShowAllExtensions -bool true
run defaults write com.apple.finder ShowPathbar -bool true
run defaults write com.apple.finder ShowStatusBar -bool true
run defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
run defaults write com.apple.finder FXDefaultSearchScope -string "SCcf" # search current folder
run defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

info "Dock: pinned left, auto-hidden, small tiles, no magnification, no recents"
run defaults write com.apple.dock orientation -string "left"
run defaults write com.apple.dock autohide -bool true
run defaults write com.apple.dock show-recents -bool false
run defaults write com.apple.dock tilesize -int 32 # slider floor is 16; 24 felt too small
run defaults write com.apple.dock magnification -bool false
run defaults write com.apple.dock mru-spaces -bool false # don't auto-rearrange Spaces

info "Spaces: give every display its own Spaces (required by OmniWM; logout required)"
run defaults write com.apple.spaces spans-displays -bool false

info "Window management: disable Stage Manager so all tiled windows remain visible"
run defaults write com.apple.WindowManager GloballyEnabled -bool false

info "Launcher: release ⌘Space / ⌥⌘Space from Spotlight so Sol can own ⌘Space"
# Symbolic hotkeys 64 (Show Spotlight search, ⌘Space) and 65 (Finder search
# window, ⌥⌘Space) are disabled; Spotlight itself (indexing, Finder search,
# the menu-bar icon) stays. Re-enable in System Settings → Keyboard → Keyboard
# Shortcuts → Spotlight. activateSettings applies it without a logout.
_spotlight_hotkey_off() { # <id> <char> <keycode> <modifiers>
  run defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" \
    "<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>$2</integer><integer>$3</integer><integer>$4</integer></array><key>type</key><string>standard</string></dict></dict>"
}
_spotlight_hotkey_off 64 32 49 1048576     # ⌘Space
_spotlight_hotkey_off 65 65535 49 1572864  # ⌥⌘Space
_activate=/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings
[ -x "$_activate" ] && { run "$_activate" -u || true; }

info "Screenshots: PNG into ~/Screenshots, no drop shadow"
run mkdir -p "$HOME/Screenshots"
run defaults write com.apple.screencapture location -string "$HOME/Screenshots"
run defaults write com.apple.screencapture type -string "png"
run defaults write com.apple.screencapture disable-shadow -bool true

info "Trackpad: tap to click, three-finger drag"
run defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
run defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true

info "Trackpad: restore native 4-finger gestures (full-screen app swipe, Mission Control)"
# Restore macOS's stock 4-finger gestures (2=on) in both trackpad domains:
# Horiz is "swipe between full-screen apps", Vert is Mission Control (up) /
# App Exposé (down). Omacase leaves these gestures under macOS control.
for dom in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  run defaults write "$dom" TrackpadFourFingerHorizSwipeGesture -int 2
  run defaults write "$dom" TrackpadFourFingerVertSwipeGesture -int 2
done

info "Misc: expanded save/print panels, no auto-correct/period-substitution"
run defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
run defaults write -g PMPrintingExpandedStateForPrint -bool true
run defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false
run defaults write -g NSAutomaticCapitalizationEnabled -bool false

info "Restarting affected apps"
for app in Dock Finder SystemUIServer; do run killall "$app" 2>/dev/null || true; done

printf '\033[32m✓\033[0m macOS defaults applied (some need a logout to fully take effect).\n'
