# shellcheck shell=bash
# mise (and its npm: tools — node, gemini, mermaid-cli, pi) left Omacase. pi is
# now the Homebrew formula pi-coding-agent (brew bundle installs it); gemini and
# mermaid-cli are dropped. Omacase owned exactly one thing here: the symlink
# ~/.config/mise/config.toml into the checkout — remove it when it is ours.
# Migrations never uninstall Homebrew packages: tell the user how instead.
migrate() {
  local cfg="$HOME/.config/mise/config.toml"
  if _is_omacase_link "$cfg"; then
    run rm -f "$cfg"
    run rmdir "$HOME/.config/mise" 2>/dev/null || true
    is_dryrun || success "Removed the Omacase-managed mise config link."
  fi
  if have mise; then
    warn "mise is no longer part of Omacase. To remove it and its tools when ready:"
    warn "  remove the mise formula with Homebrew, then: rm -rf ~/.local/share/mise ~/.local/state/mise ~/.cache/mise"
    warn "  (pi now comes from Homebrew's pi-coding-agent; gemini and mmdc are not reinstalled.)"
  fi
  return 0
}
