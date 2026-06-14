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
  # eza/ls colors are optional per theme: link when present, else CLEAR so eza
  # falls back to the terminal ANSI palette instead of the previous theme's.
  if [ -e "$src/eza" ]; then _link "$src/eza" "$cfg/eza/theme.sh"; else run rm -f "$cfg/eza/theme.sh"; fi

  is_dryrun || echo "$name" > "$OMACASE_STATE/theme"
  _theme_appearance "$name"
  _theme_claudecode "$name"
  _theme_reload
  _theme_wallpaper "$name"
  success "Theme '$name' applied."
  if ! is_dryrun; then
    source "$OMACASE_ROOT/lib/notify.sh"
    omacase_notify --title "Omacase" --subtitle "Theme" --sound Glass \
      --image "$OMACASE_ROOT/assets/omacase-icon.png" "Switched to $name"
  fi
}

# Our theme dirs mostly match Omarchy's, except the Catppuccin flavor naming.
_omarchy_name() { case "$1" in catppuccin-mocha) echo catppuccin ;; *) echo "$1" ;; esac; }

# Set the desktop wallpaper for the theme. Priority: (1) a wallpaper bundled with
# the theme (themes/<name>/background.*) — lets custom themes that have no Omarchy
# source ship their own bg; (2) a previously-fetched image cached in
# $OMACASE_DATA/backgrounds/<theme>/; (3) fetch the theme's default Omarchy bg into
# that cache and reuse it (offline after that). Failures degrade to a warning.
_theme_wallpaper() {
  local name="$1" cache="$OMACASE_DATA/backgrounds/$1" img=""
  # NB: under `set -euo pipefail`, a command substitution whose pipeline fails
  # (find on a missing dir, gh on a 404) aborts the script — so guard both and
  # swallow their status with `|| true`.
  # (1) Theme-bundled wallpaper wins. Honor a chosen alternative (`omacase
  #     wallpaper`) when this theme has it; else the primary (first `background.*`).
  local chosen; chosen="$(cat "$OMACASE_STATE/wallpaper" 2>/dev/null || echo)"
  if [ -n "$chosen" ] && [ -f "$OMACASE_ROOT/themes/$name/$chosen" ]; then
    img="$OMACASE_ROOT/themes/$name/$chosen"
  else
    img="$(find "$OMACASE_ROOT/themes/$name" -maxdepth 1 -type f -iname 'background.*' 2>/dev/null | sort | head -1)" || true
  fi
  # (2) else a fetched/cached image.
  if [ -z "$img" ] && [ -d "$cache" ]; then
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

  _set_desktop_picture "$img" "$name"
}

# Set the desktop picture to $1 (per-theme subdir $2 for staging). macOS caches
# the desktop picture by PATH: setting a path it already shows won't refresh even
# after the file's bytes change. Stage a copy named by source stem + mtime, so
# any content change OR a switch to a different bundled image is a NEW path macOS
# picks up. Best-effort; dry-run safe.
_set_desktop_picture() {
  local img="$1" name="$2"
  [ -n "$img" ] || return 0
  if is_dryrun; then printf '\033[2m[dry-run]\033[0m set wallpaper → %s\n' "$(basename "$img")"; return 0; fi
  local ext="${img##*.}" stem stamp livedir live
  stem="${img##*/}"; stem="${stem%.*}"
  stamp="$(stat -f%m "$img" 2>/dev/null || echo 0)"
  livedir="$OMACASE_DATA/backgrounds/.live/$name"
  mkdir -p "$livedir"
  live="$livedir/bg-$stem-$stamp.$ext"
  [ -f "$live" ] || cp "$img" "$live"
  find "$livedir" -type f ! -name "bg-$stem-$stamp.$ext" -delete 2>/dev/null || true
  if osascript -e "tell application \"System Events\" to set picture of every desktop to \"$live\"" >/dev/null 2>&1; then
    info "Wallpaper → $(basename "$live")"
  else
    warn "Couldn't set wallpaper (grant Automation → System Events to your terminal)."
  fi
}

# `omacase wallpaper [list|next|prev|<n>]` — choose among the active theme's
# bundled backgrounds (themes/<theme>/background*). The choice persists in
# $OMACASE_STATE/wallpaper and carries to any theme that has a same-named file
# (so e.g. the 2nd background follows you between techno-viking and -light).
omacase_wallpaper() {
  ensure_brew_env
  local theme dir; theme="$(cat "$OMACASE_STATE/theme" 2>/dev/null || echo)"
  [ -n "$theme" ] || abort "no active theme — run \`omacase theme\` first."
  dir="$OMACASE_ROOT/themes/$theme"
  local bgs; bgs="$(cd "$dir" 2>/dev/null && ls -1 background* 2>/dev/null | sort)"
  [ -n "$bgs" ] || abort "theme '$theme' has no bundled backgrounds."
  local count; count="$(printf '%s\n' "$bgs" | grep -c .)"

  local cur; cur="$(cat "$OMACASE_STATE/wallpaper" 2>/dev/null || echo)"
  printf '%s\n' "$bgs" | grep -qxF "$cur" || cur="$(printf '%s\n' "$bgs" | head -1)"
  local idx; idx="$(printf '%s\n' "$bgs" | grep -nxF "$cur" | head -1 | cut -d: -f1)"; idx=$((idx - 1))

  local chosen=""
  case "${1:-list}" in
    list|"")
      info "Backgrounds for '$theme' (● = current):"
      printf '%s\n' "$bgs" | awk -v c="$cur" '{printf "  %s %s\n", ($0==c?"\xe2\x97\x8f":" "), $0}'
      return 0 ;;
    pick)   # gum-pick (used by `omacase menu`)
      [ "$count" -gt 1 ] || { info "Only one background bundled for '$theme'."; return 0; }
      chosen="$(gum_choose "Wallpaper · $theme" $bgs)" || return 0 ;;
    next)   chosen="$(printf '%s\n' "$bgs" | sed -n "$(( (idx + 1) % count + 1 ))p")" ;;
    prev)   chosen="$(printf '%s\n' "$bgs" | sed -n "$(( (idx - 1 + count) % count + 1 ))p")" ;;
    [1-9]*) local n=$(( $1 - 1 )); { [ "$n" -ge 0 ] && [ "$n" -lt "$count" ]; } || abort "pick 1-$count"
            chosen="$(printf '%s\n' "$bgs" | sed -n "$((n + 1))p")" ;;
    *) abort "usage: omacase wallpaper [list|next|prev|pick|<n>]" ;;
  esac

  [ -n "$chosen" ] || return 0
  is_dryrun || echo "$chosen" > "$OMACASE_STATE/wallpaper"
  _set_desktop_picture "$dir/$chosen" "$theme"
  success "wallpaper → $chosen ($theme)"
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
