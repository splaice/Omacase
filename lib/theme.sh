# shellcheck shell=bash
# `macarchy theme [name]` — apply one theme to every app at once. A theme is a
# directory under themes/<name>/ containing per-app fragments that get symlinked
# or rendered into the live config locations.

macarchy_theme() {
  local name="${1:-}"
  local themes_dir="$MACARCHY_ROOT/themes"

  if [ -z "$name" ]; then
    name="$(gum_choose "Pick a theme" $(_theme_list))" || return
  fi
  local src="$themes_dir/$name"
  [ -d "$src" ] || abort "Unknown theme '$name'. Available: $(_theme_list | tr '\n' ' ')"

  info "Applying theme: $name"
  # Each app reads a single 'current' file that we point at the chosen theme.
  # Apps include this file from their main config (see home/dot_config/*).
  local cfg="$HOME/.config"
  _link "$src/ghostty"    "$cfg/ghostty/theme"
  _link "$src/sketchybar" "$cfg/sketchybar/theme.sh"
  _link "$src/borders"    "$cfg/borders/theme.conf"
  _link "$src/btop"       "$cfg/btop/themes/current.theme"
  _link "$src/nvim.lua"   "$cfg/nvim/lua/theme.lua"
  _link "$src/starship"   "$cfg/starship/theme.toml"

  is_dryrun || echo "$name" > "$MACARCHY_STATE/theme"
  _theme_reload
  success "Theme '$name' applied."
}

_theme_list() { ls -1 "$MACARCHY_ROOT/themes" 2>/dev/null; }

_link() { # _link <src> <dest>  (only if src exists)
  [ -e "$1" ] || return 0
  run mkdir -p "$(dirname "$2")"
  run ln -sfn "$1" "$2"
}

_theme_reload() {
  # Live-reload anything already running; ignore if not.
  pgrep -x sketchybar >/dev/null && run sketchybar --reload || true
  pgrep -x borders   >/dev/null && run brew services restart borders 2>/dev/null || true
  # Ghostty/nvim pick up theme on next launch or via their own reload binds.
}
