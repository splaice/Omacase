#!/bin/bash
# macarchy macOS defaults — the `defaults write` layer (the .config analog).
# Idempotent: each key is set to a fixed value, so re-running is a no-op.
# Many changes need a relaunch of Dock/Finder/SystemUIServer (done at the end)
# or a full logout to fully apply.
set -euo pipefail

info() { printf '\033[34m➜\033[0m %s\n' "$*"; }

info "Keyboard: fast key repeat, disable press-and-hold (enables key-repeat in vim/etc.)"
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15

info "Finder: show extensions, path/status bar, POSIX path title, no .DS_Store on network"
defaults write -g AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf" # search current folder
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

info "Dock: autohide fast, no recents, smaller icons (out of the WM's way)"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock tilesize -int 40
defaults write com.apple.dock mru-spaces -bool false # don't auto-rearrange Spaces

info "Screenshots: PNG into ~/Screenshots, no drop shadow"
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

info "Trackpad: tap to click, three-finger drag"
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true

info "Misc: expanded save/print panels, no auto-correct/period-substitution"
defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
defaults write -g PMPrintingExpandedStateForPrint -bool true
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write -g NSAutomaticCapitalizationEnabled -bool false

info "Restarting affected apps"
for app in Dock Finder SystemUIServer; do killall "$app" 2>/dev/null || true; done

printf '\033[32m✓\033[0m macOS defaults applied (some need a logout to fully take effect).\n'
