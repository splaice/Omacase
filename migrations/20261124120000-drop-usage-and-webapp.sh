# shellcheck shell=bash
# `omacase usage` (agent usage dashboard + its usage-tracker extra) and
# `omacase webapp` left Omacase. Unload and remove the tracker's LaunchAgent if
# it was enabled; leave the collected state records for the user to delete.
migrate() {
  local agent="$HOME/Library/LaunchAgents/org.omacase.usage.plist"
  # Ownership: only the plist our extra generated (its Label is ours).
  if [ -f "$agent" ] && grep -q "<string>org.omacase.usage</string>" "$agent"; then
    run launchctl bootout "gui/$(id -u)/org.omacase.usage" 2>/dev/null || true
    run rm -f "$agent"
    success "Removed the usage-tracker LaunchAgent"
  fi
  if [ -d "$OMACASE_STATE/usage" ]; then
    info "$OMACASE_STATE/usage is no longer read by anything; delete it when ready."
  fi
  return 0
}
