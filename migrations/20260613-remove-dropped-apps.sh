# shellcheck shell=bash
# Remove the apps/tap that Omacase used to ship and has since dropped:
#   - Ice  (jordanbaird-ice) — the menu bar is stock macOS now
#   - Zed  (zed)             — Omacase is Neovim-centric
#   - yabai + skhd           — AeroSpace is the only window-manager profile
#   - koekeishiya/formulae   — the tap yabai/skhd came from
#
# SCOPE: only these exact Omacase-managed names, each guarded by "is it actually
# installed". Nothing here removes a package merely for being absent from the
# Brewfile (no `brew bundle cleanup`), so a user's own Homebrew installs are
# untouched. Plain uninstall (no --zap) so app preferences/data are left intact —
# anyone who wants those gone can remove them by hand.
migrate() {
  local cask
  for cask in jordanbaird-ice zed; do
    if brew list --cask "$cask" >/dev/null 2>&1; then
      run brew uninstall --cask "$cask" || warn "migrate: couldn't uninstall cask '$cask' (skipped)."
    fi
  done

  local formula
  for formula in yabai skhd; do
    if brew list --formula "$formula" >/dev/null 2>&1; then
      run brew uninstall "$formula" || warn "migrate: couldn't uninstall '$formula' (skipped)."
    fi
  done

  # Untap only once nothing from it remains installed (uninstalls above run first).
  if brew tap 2>/dev/null | grep -qx "koekeishiya/formulae"; then
    run brew untap koekeishiya/formulae || warn "migrate: couldn't untap koekeishiya/formulae (skipped)."
  fi
}
