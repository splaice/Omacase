# shellcheck shell=bash
# OmniWM, Brave Browser, and OmacaseLauncher left Omacase: window management is
# stock macOS, `omacase webapp` uses Chrome, and nothing launches at login.
# Remove the generated launcher bundle + LaunchAgent (ownership-checked), and
# leave the dropped casks installed (migrations never uninstall Homebrew
# packages) — just say how.
migrate() {
  # shellcheck source=/dev/null
  source "$OMACASE_ROOT/lib/install.sh"
  _remove_legacy_launchers
  if [ -d /Applications/OmniWM.app ]; then
    warn "OmniWM is no longer part of Omacase. Remove the omniwm cask with Homebrew when ready; ~/.config/omniwm stays until you delete it."
  fi
  if [ -d "/Applications/Brave Browser.app" ]; then
    warn "Brave Browser is no longer part of Omacase (\`omacase webapp\` uses Chrome). Remove the brave-browser cask with Homebrew when ready."
  fi
  if [ -f "$HOME/.config/omacase/login-items" ]; then
    info "$HOME/.config/omacase/login-items is no longer read by anything; delete it when ready."
  fi
  return 0
}
