# shellcheck shell=bash
# yolobox left the Brewfile: Omacase no longer ships a sandboxed agent runner.
# Migrations never uninstall Homebrew packages (see lib/migrate.sh); tell the
# user how to remove it explicitly instead. Best-effort by design.
migrate() {
  if have yolobox; then
    warn "yolobox is no longer part of Omacase. Remove it explicitly when ready:"
    warn "  \`yolobox uninstall --force\`, then remove the yolobox formula and untap finbarr/tap with Homebrew."
  fi
  return 0
}
