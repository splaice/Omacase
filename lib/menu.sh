# shellcheck shell=bash
# `omacase menu` — the gum TUI, the omarchy-menu analog. Run it from a terminal,
# or wrap `omacase menu` in a Shortcut to launch it from Spotlight / a hotkey.
# Output-only commands, aliases, automation helpers, and commands that launch
# this menu are intentionally not duplicated as menu entries.

omacase_menu() {
  local choice
  choice="$(gum_choose "Omacase" \
    "Install / repair" \
    "Update everything" \
    "Switch theme" \
    "Edit theme palette" \
    "Switch wallpaper" \
    "Toggle Light / Dark" \
    "Open a web app" \
    "Apps and overlays" \
    "Start / verify OmniWM" \
    "OmniWM app menu" \
    "OmniWM command palette" \
    "OmniWM settings" \
    "View keybinds" \
    "Run doctor" \
    "Create a backup" \
    "Restore a backup" \
    "Run migrations" \
    "Edit config" \
    "About" \
    "Uninstall Omacase" \
    "Quit")" || return

  case "$choice" in
    "Install / repair")        source "$OMACASE_ROOT/lib/install.sh"; omacase_install ;;
    "Update everything")     source "$OMACASE_ROOT/lib/update.sh"; omacase_update ;;
    "About")                 if have fastfetch; then fastfetch; else warn "fastfetch not installed — run \`omacase install\`"; fi ;;
    "Switch theme")          source "$OMACASE_ROOT/lib/theme.sh";  omacase_theme ;;
    "Edit theme palette")    source "$OMACASE_ROOT/lib/palette.sh"; omacase_palette ;;
    "Switch wallpaper")      source "$OMACASE_ROOT/lib/theme.sh";  omacase_wallpaper pick ;;
    "Toggle Light / Dark")   source "$OMACASE_ROOT/lib/actions.sh"; omacase_appearance toggle ;;
    "Open a web app")        _menu_webapp ;;
    "Apps and overlays")     _menu_apps ;;
    "Start / verify OmniWM")  source "$OMACASE_ROOT/lib/wm.sh";    omacase_wm ;;
    "OmniWM app menu")        source "$OMACASE_ROOT/lib/wm.sh";    omacase_wm menu ;;
    "OmniWM command palette") source "$OMACASE_ROOT/lib/wm.sh";    omacase_wm palette ;;
    "OmniWM settings")        source "$OMACASE_ROOT/lib/wm.sh";    omacase_wm settings ;;
    "View keybinds")         source "$OMACASE_ROOT/lib/keybinds.sh"; omacase_keybinds ;;
    "Run doctor")            source "$OMACASE_ROOT/lib/doctor.sh"; omacase_doctor ;;
    "Create a backup")       source "$OMACASE_ROOT/lib/backup.sh"; omacase_backup ;;
    "Restore a backup")      source "$OMACASE_ROOT/lib/backup.sh"; omacase_restore ;;
    "Run migrations")        source "$OMACASE_ROOT/lib/migrate.sh"; omacase_migrate ;;
    "Edit config")           exec sh -c 'exec ${EDITOR:-open} "$1"' sh "$OMACASE_ROOT/home" ;;   # sh splits multi-word EDITORs like "code -w"
    "Uninstall Omacase")     source "$OMACASE_ROOT/lib/install.sh"; omacase_uninstall ;;
    "Quit"|"")               return ;;
  esac
}

_menu_webapp() {
  source "$OMACASE_ROOT/lib/actions.sh"
  local choice
  local -a apps
  read -r -a apps <<< "$_webapp_names"
  choice="$(gum_choose "Web app" "${apps[@]}" "Back")" || return
  [ "$choice" = "Back" ] || omacase_webapp "$choice"
}
_menu_apps() {
  local choice
  choice="$(gum_choose "Apps and overlays" \
    "New terminal" \
    "File manager" \
    "Browser" \
    "Spotify" \
    "Apple Music" \
    "Obsidian" \
    "1Password" \
    "Messages" \
    "Todoist" \
    "Back")" || return
  source "$OMACASE_ROOT/lib/wm.sh"
  case "$choice" in
    "New terminal") omacase_terminal ;;
    "File manager") omacase_files ;;
    "Browser")      omacase_browser ;;
    "Spotify")      omacase_music spotify ;;
    "Apple Music")  omacase_music apple ;;
    "Obsidian")     omacase_obsidian ;;
    "1Password")    omacase_1password ;;
    "Messages")     omacase_message ;;
    "Todoist")      omacase_todoist ;;
    "Back"|"")      return ;;
  esac
}
