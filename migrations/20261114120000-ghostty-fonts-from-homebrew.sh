# shellcheck shell=bash
# Ghostty's fonts moved to Homebrew casks (Maple Mono NF → JuliaMono → Noto
# Color Emoji). Remove the retired IoskeleyMono release install — only when
# Omacase's marker proves we put it there — and leave the dropped JetBrains
# Mono cask installed (migrations never uninstall Homebrew packages).
migrate() {
  local d="$HOME/Library/Fonts/IoskeleyMono-Term-NerdFont"
  if [ -f "$d/.omacase-version" ]; then
    run rm -rf "$d"
  fi
  if [ -n "$(ls "$HOME"/Library/Fonts/JetBrainsMonoNerdFont* 2>/dev/null)" ]; then
    warn "JetBrains Mono Nerd Font is no longer part of Omacase (Ghostty uses Maple Mono NF). Remove the font-jetbrains-mono-nerd-font cask with Homebrew when ready."
  fi
  return 0
}
