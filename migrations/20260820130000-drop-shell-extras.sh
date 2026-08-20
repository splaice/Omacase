# shellcheck shell=bash
# direnv, zoxide, dust, lazygit and The Unarchiver left the Brewfile (unused in
# practice; the zsh hooks for direnv/zoxide and the `lg` alias are gone from the
# managed ~/.zshrc). Migrations never uninstall Homebrew packages: say how.
migrate() {
  local f left=""
  for f in direnv zoxide dust lazygit; do have "$f" && left="$left $f"; done
  [ -d "/Applications/The Unarchiver.app" ] && left="$left the-unarchiver(cask)"
  if [ -n "$left" ]; then
    warn "No longer part of Omacase:$left. Remove them with Homebrew when ready"
    warn "  (zoxide keeps a db in ~/Library/Application Support/zoxide; direnv in ~/.local/share/direnv)."
  fi
  return 0
}
