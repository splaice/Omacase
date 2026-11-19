# shellcheck shell=bash
# atuin left the Brewfile and ~/.zshrc: history is stock zsh (~/.zsh_history).
# Migrations never uninstall Homebrew packages: say how.
migrate() {
  if have atuin; then
    warn "atuin is no longer part of Omacase (shell history is stock zsh). Remove it with Homebrew when ready; its history stays in ~/.local/share/atuin until you delete it."
  fi
  return 0
}
