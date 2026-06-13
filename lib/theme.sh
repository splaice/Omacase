# shellcheck shell=bash
# `omacase theme [name]` — apply one theme to every app at once. A theme is a
# directory under themes/<name>/ containing per-app fragments that get symlinked
# or rendered into the live config locations.

omacase_theme() {
  local name="${1:-}"
  local themes_dir="$OMACASE_ROOT/themes"

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

  is_dryrun || echo "$name" > "$OMACASE_STATE/theme"
  _theme_appearance "$name"
  _theme_claudecode "$name"
  _theme_reload
  _theme_wallpaper "$name"
  success "Theme '$name' applied."
  if ! is_dryrun; then
    source "$OMACASE_ROOT/lib/notify.sh"
    omacase_notify --title "Omacase" --subtitle "Theme" --sound Glass "Switched to $name"
  fi
}

# Our theme dirs mostly match Omarchy's, except the Catppuccin flavor naming.
_omarchy_name() { case "$1" in catppuccin-mocha) echo catppuccin ;; *) echo "$1" ;; esac; }

# Set the desktop wallpaper to the theme's default Omarchy background. Images
# aren't bundled — the first time a theme is used we fetch its default bg into
# $OMACASE_DATA/backgrounds/<theme>/ and reuse it thereafter (offline after
# that). Network/tool/offline failures degrade to a warning, never an abort.
_theme_wallpaper() {
  local name="$1" cache="$OMACASE_DATA/backgrounds/$1" img=""
  # NB: under `set -euo pipefail`, a command substitution whose pipeline fails
  # (find on a missing dir, gh on a 404) aborts the script — so guard both and
  # swallow their status with `|| true`.
  if [ -d "$cache" ]; then
    img="$(find "$cache" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | sort | head -1)" || true
  fi

  if [ -z "$img" ]; then
    is_dryrun && { printf '\033[2m[dry-run]\033[0m fetch+set wallpaper for %s\n' "$name"; return 0; }
    have curl || return 0
    local on file=""
    on="$(_omarchy_name "$name")"
    # List the theme's backgrounds via the public GitHub contents API (no auth,
    # plain curl) and pick the default: first real image, skipping the logo.
    file="$(curl -fsSL "https://api.github.com/repos/basecamp/omarchy/contents/themes/$on/backgrounds" 2>/dev/null \
            | grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/' \
            | grep -iE '\.(jpg|jpeg|png)$' | grep -ivE '^omarchy\.' | sort | head -1)" || true
    [ -n "$file" ] || { info "No wallpaper available for $name (skipped)."; return 0; }
    mkdir -p "$cache"
    if curl -fsSL "https://raw.githubusercontent.com/basecamp/omarchy/master/themes/$on/backgrounds/$file" \
         -o "$cache/$file" 2>/dev/null && [ -s "$cache/$file" ]; then
      img="$cache/$file"
    else
      rm -f "$cache/$file"; warn "Couldn't download wallpaper for $name (offline?) — skipped."; return 0
    fi
  fi

  [ -n "$img" ] || return 0
  if osascript -e "tell application \"System Events\" to set picture of every desktop to \"$img\"" >/dev/null 2>&1; then
    info "Wallpaper → $(basename "$img")"
  else
    warn "Couldn't set wallpaper (grant Automation → System Events to your terminal)."
  fi
}

# Keep Claude Code's UI theme in step with the omacase theme's brightness.
# Claude reads ~/.claude/settings.json ("theme"); built-in themes apply on its
# next launch (only custom themes hot-reload). We flip just the light/dark part,
# preserving a -daltonized/-ansi variant and never fighting an explicit "auto".
# jq edits in place so every other setting is left untouched.
_theme_claudecode() {
  local settings="$HOME/.claude/settings.json"
  have jq || return 0
  [ -f "$settings" ] || return 0
  local want=dark; _theme_is_light "$1" && want=light
  local cur; cur="$(jq -r '.theme // ""' "$settings" 2>/dev/null)"
  [ "$cur" = auto ] && return 0
  local suffix=""; case "$cur" in *-daltonized) suffix=-daltonized ;; *-ansi) suffix=-ansi ;; esac
  local new="$want$suffix"
  [ "$cur" = "$new" ] && return 0
  if is_dryrun; then printf '\033[2m[dry-run]\033[0m Claude Code theme → %s\n' "$new"; return 0; fi
  local tmp; tmp="$(mktemp)"
  if jq --arg t "$new" '.theme = $t' "$settings" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    mv "$tmp" "$settings"
    info "Claude Code theme → $new (applies on its next launch)"
  else
    rm -f "$tmp"
  fi
}

_theme_list() { ls -1 "$OMACASE_ROOT/themes" 2>/dev/null; }

# Light vs dark is derived from the theme's SketchyBar BAR_COLOR (0xffRRGGBB)
# using perceived luminance, so it stays correct for every theme with no
# per-theme flag to maintain. Returns 0 (true) when the background is light.
_theme_is_light() {
  local f="$OMACASE_ROOT/themes/$1/sketchybar" hex
  hex="$(sed -n 's/.*BAR_COLOR=0[xX][fF][fF]\([0-9a-fA-F]\{6\}\).*/\1/p' "$f" 2>/dev/null | head -1)"
  [ -n "$hex" ] || return 1   # unknown/empty background → treat as dark
  local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
  # Rec. 601 luma scaled by 1000 to stay in integer math; >128 ≈ light.
  [ $(( (299*r + 587*g + 114*b) / 1000 )) -gt 128 ]
}

# Match macOS system appearance to the theme's brightness at switch time.
_theme_appearance() {
  local dark=true
  _theme_is_light "$1" && dark=false
  info "macOS appearance → $([ "$dark" = true ] && echo Dark || echo Light)"
  # System Events drives the global Light/Dark toggle; needs Automation consent
  # for the controlling terminal (granted once, on first prompt).
  run osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark" >/dev/null 2>&1 \
    || warn "Couldn't set macOS appearance (grant Automation to your terminal: System Settings → Privacy & Security → Automation)."
}

_link() { # _link <src> <dest>  (only if src exists)
  [ -e "$1" ] || return 0
  run mkdir -p "$(dirname "$2")"
  run ln -sfn "$1" "$2"
}

_theme_reload() {
  # Live-reload anything already running; ignore if not.
  pgrep -x sketchybar >/dev/null && run sketchybar --reload || true
  pgrep -x borders   >/dev/null && run brew services restart splaice/formulae/borders 2>/dev/null || true
  # Ghostty reloads its config (and the theme include) on SIGUSR2 since 1.2,
  # which also refreshes ANSI-palette CLIs like eza/ls. CAUTION: any OTHER
  # signal makes Ghostty quit. macOS truncates `comm` and hides GUI argv from
  # pgrep, so find the GUI process precisely via ps: args is exactly the binary
  # path with no extra args (NF==2), which excludes `ghostty +cmd` CLI runs.
  local gpid
  gpid="$(ps -Axo pid=,args= | awk '$2=="/Applications/Ghostty.app/Contents/MacOS/ghostty" && NF==2 {print $1}')"
  [ -n "$gpid" ] && run kill -USR2 $gpid || true
  # nvim picks up the theme on next launch or via its own reload bind.
}
