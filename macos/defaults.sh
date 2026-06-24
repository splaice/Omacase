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

info "Dock: autohide fast, no recents, smaller icons (out of the WM's way)"
run defaults write com.apple.dock autohide -bool true
run defaults write com.apple.dock autohide-delay -float 0
run defaults write com.apple.dock autohide-time-modifier -float 0.15
run defaults write com.apple.dock show-recents -bool false
run defaults write com.apple.dock tilesize -int 40
run defaults write com.apple.dock mru-spaces -bool false # don't auto-rearrange Spaces

info "Screenshots: PNG into ~/Screenshots, no drop shadow"
run mkdir -p "$HOME/Screenshots"
run defaults write com.apple.screencapture location -string "$HOME/Screenshots"
run defaults write com.apple.screencapture type -string "png"
run defaults write com.apple.screencapture disable-shadow -bool true

info "Trackpad: tap to click, three-finger drag"
run defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
run defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true

info "Trackpad: 4-finger horizontal swipe → cycle AeroSpace workspaces (via SwipeAeroSpace)"
# SwipeAeroSpace owns the 4-finger horizontal swipe; preset before first launch.
run defaults write club.mediosz.SwipeAeroSpace fingers -string "Four"
run defaults write club.mediosz.SwipeAeroSpace wrap -bool true
# Reserve all 4-finger swipes for AeroSpace by disabling macOS's native
# 4-finger gestures (0=off) in both trackpad domains: Horiz is "swipe between
# full-screen apps", Vert is Mission Control (up) / App Exposé (down) — one key
# covers both directions. 3-finger stays on (2) for macOS Spaces & Mission
# Control, so the native and AeroSpace gestures don't both fire on one swipe.
for dom in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  run defaults write "$dom" TrackpadFourFingerHorizSwipeGesture -int 0
  run defaults write "$dom" TrackpadFourFingerVertSwipeGesture -int 0
done

info "Misc: expanded save/print panels, no auto-correct/period-substitution"
run defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
run defaults write -g PMPrintingExpandedStateForPrint -bool true
run defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false
run defaults write -g NSAutomaticCapitalizationEnabled -bool false

info "Restarting affected apps"
for app in Dock Finder SystemUIServer; do run killall "$app" 2>/dev/null || true; done

printf '\033[32m✓\033[0m macOS defaults applied (some need a logout to fully take effect).\n'
