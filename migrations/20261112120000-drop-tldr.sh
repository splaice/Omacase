# shellcheck shell=bash
# tldr left the Brewfile. Migrations never uninstall Homebrew packages: say how.
migrate() {
  if have tldr; then
    warn "tldr is no longer part of Omacase. Remove it with Homebrew when ready."
  fi
  return 0
}
