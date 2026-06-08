# shellcheck shell=bash
# `macarchy menu` — the gum TUI, the omarchy-menu analog. Bind to a Raycast
# hotkey (Raycast → Script Commands → run `macarchy menu`).

macarchy_menu() {
  local choice
  choice="$(gum_choose "macarchy" \
    "Update everything" \
    "Switch theme" \
    "Switch window manager" \
    "Run doctor" \
    "Edit config" \
    "Quit")" || return

  case "$choice" in
    "Update everything")     source "$MACARCHY_ROOT/lib/update.sh"; macarchy_update ;;
    "Switch theme")          source "$MACARCHY_ROOT/lib/theme.sh";  macarchy_theme ;;
    "Switch window manager") source "$MACARCHY_ROOT/lib/wm.sh";     macarchy_wm ;;
    "Run doctor")            source "$MACARCHY_ROOT/lib/doctor.sh"; macarchy_doctor ;;
    "Edit config")           exec "${EDITOR:-open}" "$MACARCHY_ROOT/home" ;;
    "Quit"|"")               return ;;
  esac
}
