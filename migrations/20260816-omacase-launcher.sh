# shellcheck shell=bash
# The OmniWM login item used to be a raw LaunchAgent running `/usr/bin/open`,
# which System Settings → Login Items displayed as a bare "open" row. Login
# launches now go through ~/Applications/OmacaseLauncher.app (agent
# org.omacase.launcher, apps listed in ~/.config/omacase/login-items), so the
# pane shows an honest "OmacaseLauncher". Swap the old agent for the launcher.
#
# Idempotent: the old-agent removal is guarded by presence, and
# _launcher_install rebuilds the same bundle/agent on every run.
migrate() {
  local old="$HOME/Library/LaunchAgents/org.omacase.omniwm.plist"
  if [ -e "$old" ] || [ -L "$old" ]; then
    run launchctl bootout "gui/$(id -u)/org.omacase.omniwm" 2>/dev/null || true
    run rm -f "$old"
  fi
  # shellcheck source=/dev/null
  source "$OMACASE_ROOT/lib/launcher.sh"
  _launcher_install
}
