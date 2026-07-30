# shellcheck shell=bash
# Complete the one-time transition from Omacase's previous desktop stack to
# OmniWM. These are exact packages, links, generated helpers, and state files
# that Omacase itself installed; unrelated user files and Homebrew packages are
# deliberately left alone.
migrate() {
  # Stop desktop processes before uninstalling their packages.
  run osascript -e 'tell application "AeroSpace" to quit' >/dev/null 2>&1 || true
  if brew list --formula sketchybar >/dev/null 2>&1; then
    run brew services stop sketchybar >/dev/null 2>&1 || true
    run brew uninstall sketchybar || warn "migrate: couldn't uninstall 'sketchybar' (skipped)."
  fi
  if brew list --formula borders >/dev/null 2>&1; then
    run brew services stop splaice/formulae/borders >/dev/null 2>&1 ||
      run brew services stop borders >/dev/null 2>&1 || true
    run brew uninstall borders || warn "migrate: couldn't uninstall 'borders' (skipped)."
  fi

  local cask
  for cask in aerospace karabiner-elements; do
    if brew list --cask "$cask" >/dev/null 2>&1; then
      run brew uninstall --cask "$cask" ||
        warn "migrate: couldn't uninstall cask '$cask' (skipped)."
    fi
  done

  # Remove only links that still point into Omacase and exact helper files that
  # the old SketchyBar/btop integrations generated.
  source "$OMACASE_ROOT/lib/backup.sh"
  local owned
  for owned in \
    "$HOME/.config/aerospace/aerospace.toml" \
    "$HOME/.config/borders/bordersrc" \
    "$HOME/.config/borders/theme.conf" \
    "$HOME/.config/karabiner/karabiner.json" \
    "$HOME/.config/sketchybar/sketchybarrc" \
    "$HOME/.config/sketchybar/theme.sh" \
    "$HOME/Library/Fonts/OmacaseIcons.ttf"
  do
    { _is_omacase_link "$owned" && run rm -f "$owned"; } || true
  done

  local generated
  for generated in \
    "$HOME/.config/sketchybar/spaces.sh" \
    "$HOME/.config/sketchybar/space_handler.sh" \
    "$HOME/.config/sketchybar/sysstats.sh" \
    "$HOME/.config/btop/omacase-popup.conf"
  do
    [ -e "$generated" ] || [ -L "$generated" ] || continue
    run rm -f "$generated"
  done

  # Stop only the exact caffeinate process recorded by Omacase's old helper.
  local caffeine_pidfile="$OMACASE_STATE/caffeinate.pid" caffeine_pid="" caffeine_cmd=""
  caffeine_pid="$(cat "$caffeine_pidfile" 2>/dev/null || true)"
  caffeine_pid="${caffeine_pid%% *}"
  if [ -n "$caffeine_pid" ] && kill -0 "$caffeine_pid" 2>/dev/null; then
    caffeine_cmd="$(ps -p "$caffeine_pid" -o command= 2>/dev/null | sed 's/^ *//')"
    if [ "$caffeine_cmd" = "/usr/bin/caffeinate -d -i" ]; then
      run kill "$caffeine_pid" 2>/dev/null || true
    fi
  fi
  run rm -f "$caffeine_pidfile" "$OMACASE_STATE/wm"
  local login_name="${USER:-$(id -un)}" workspace
  run rm -f \
    "${TMPDIR:-/tmp}/omacase-centered-$login_name" \
    "${TMPDIR:-/tmp}/omacase-retile-$login_name.lock"
  for workspace in 1 2 3 4 5 6 7 8 9; do
    run rm -f "${TMPDIR:-/tmp}/omacase-retile-$login_name-ws$workspace"
  done

  local dir
  for dir in \
    "$HOME/.config/aerospace" \
    "$HOME/.config/borders" \
    "$HOME/.config/karabiner" \
    "$HOME/.config/sketchybar"
  do
    run rmdir "$dir" 2>/dev/null || true
  done

  local tap
  for tap in nikitabobko/tap FelixKratz/formulae splaice/formulae; do
    if brew tap 2>/dev/null | grep -Fxiq "$tap"; then
      run brew untap "$tap" ||
        warn "migrate: couldn't untap '$tap' (it may still provide another installed package)."
    fi
  done
}
