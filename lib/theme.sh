# shellcheck shell=bash
# `omacase theme [name]` — apply one theme to every app at once.
#
# Omarchy-derived themes are not vendored as per-app fragments. We download the
# upstream MIT-licensed colors.toml into OMACASE_DATA and render the Ghostty,
# SketchyBar, JankyBorders, btop, Neovim, and Starship fragments locally.

_THEME_MANIFEST="$OMACASE_ROOT/themes/manifest"

# "fragment|live target" pairs — the single source of truth for the symlinks
# `omacase theme` creates; uninstall walks the same list to remove them.
_theme_links() {
  printf '%s\n' \
    "ghostty|$HOME/.config/ghostty/theme" \
    "sketchybar|$HOME/.config/sketchybar/theme.sh" \
    "borders|$HOME/.config/borders/theme.conf" \
    "btop|$HOME/.config/btop/themes/current.theme" \
    "nvim.lua|$HOME/.config/nvim/lua/theme.lua" \
    "starship|$HOME/.config/starship/theme.toml"
}

omacase_theme() {
  local name="${1:-}"

  if [ -z "$name" ]; then
    name="$(gum_choose "Pick a theme" $(_theme_list))" || return
  fi
  _theme_known "$name" || abort "Unknown theme '$name'. Available: $(_theme_list | tr '\n' ' ')"

  info "Applying theme: $name"
  local src; src="$(_theme_materialize "$name")"

  # Each app reads a single 'current' file that we point at the chosen theme.
  # Apps include this file from their main config (see home/dot_config/*).
  local frag target
  while IFS='|' read -r frag target; do
    _link "$src/$frag" "$target"
  done < <(_theme_links)
  # NB: eza (ls), ranger, and glow are NOT linked per theme. Their colors are
  # ANSI palette indices (configured once in zshrc / their dotfiles), so they
  # track whichever theme is active automatically — Ghostty swaps the 16 ANSI
  # colors per theme, and greyscale themes (white, vantablack) render monochrome.

  if ! is_dryrun; then
    ensure_state_dir
    echo "$name" > "$OMACASE_STATE/theme"
  fi
  _theme_appearance "$name"
  _theme_claudecode "$name"
  _theme_reload
  _theme_wallpaper "$name"
  success "Theme '$name' applied."
  is_dryrun || notify --subtitle "Theme" --sound Glass "Switched to $name"
}

_theme_field() {
  local name="$1" col="$2"
  awk -F'|' -v n="$name" -v c="$col" '
    $0 !~ /^#/ && $1 == n { print $c; found = 1; exit }
    END { exit found ? 0 : 1 }
  ' "$_THEME_MANIFEST"
}

_theme_known() { _theme_field "$1" 1 >/dev/null 2>&1; }
_theme_title() { _theme_field "$1" 2; }
_theme_source() { _theme_field "$1" 3; }
_omarchy_name() { _theme_field "$1" 4; }
_theme_nvim() { _theme_field "$1" 5; }
_theme_generated_dir() { printf '%s/generated/themes/%s\n' "$OMACASE_DATA" "$1"; }

_theme_materialize() {
  local name="$1" source
  source="$(_theme_source "$name")" || return 1

  if [ "$source" = local ]; then
    local local_dir="$OMACASE_ROOT/themes/$name"
    [ -d "$local_dir" ] || abort "local theme '$name' is missing: $local_dir"
    printf '%s\n' "$local_dir"
    return 0
  fi

  local out colors upstream title nvim
  out="$(_theme_generated_dir "$name")"
  if [ -z "${OMACASE_THEME_REFRESH:-}" ] &&
     [ -s "$out/ghostty" ] && [ -s "$out/sketchybar" ] && [ -s "$out/borders" ] &&
     [ -s "$out/btop" ] && [ -s "$out/nvim.lua" ] && [ -s "$out/starship" ]; then
    printf '%s\n' "$out"
    return 0
  fi

  if is_dryrun; then
    printf '%s\n' "$out"
    return 0
  fi

  upstream="$(_omarchy_name "$name")"
  title="$(_theme_title "$name")"
  nvim="$(_theme_nvim "$name")"
  colors="$OMACASE_DATA/upstream/omarchy/themes/$upstream/colors.toml"
  _theme_download_omarchy_colors "$upstream" "$colors" ||
    abort "could not download Omarchy colors for '$name' ($upstream), and no cache exists."
  _theme_render_from_colors "$name" "$title" "$nvim" "$colors" "$out"
  printf '%s\n' "$out"
}

_theme_download_omarchy_colors() {
  local upstream="$1" dest="$2" ref="${OMACASE_OMARCHY_REF:-master}" tmp
  if [ -z "${OMACASE_THEME_REFRESH:-}" ] && [ -s "$dest" ]; then return 0; fi
  have curl || { [ -s "$dest" ]; return; }
  mkdir -p "$(dirname "$dest")"
  tmp="$dest.tmp.$$"
  if curl -fsSL "https://raw.githubusercontent.com/basecamp/omarchy/$ref/themes/$upstream/colors.toml" \
      -o "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    mv "$tmp" "$dest"
    return 0
  fi
  rm -f "$tmp"
  [ -s "$dest" ]
}

_theme_color() {
  local file="$1" key="$2"
  sed -nE "s/^[[:space:]]*$key[[:space:]]*=[[:space:]]*\"#?([0-9A-Fa-f]{6})\".*/\1/p" "$file" |
    head -1 | tr 'A-F' 'a-f'
}

_theme_render_from_colors() {
  local name="$1" title="$2" nvim="$3" colors="$4" out="$5"
  local accent cursor fg bg sel_fg sel_bg tmp palette arrow
  local -a pal

  accent="$(_theme_color "$colors" accent)"
  cursor="$(_theme_color "$colors" cursor)"
  fg="$(_theme_color "$colors" foreground)"
  bg="$(_theme_color "$colors" background)"
  sel_fg="$(_theme_color "$colors" selection_foreground)"
  sel_bg="$(_theme_color "$colors" selection_background)"
  for i in {0..15}; do
    pal[$i]="$(_theme_color "$colors" "color$i")"
  done

  [ -n "$accent" ] && [ -n "$cursor" ] && [ -n "$fg" ] && [ -n "$bg" ] &&
    [ -n "$sel_fg" ] && [ -n "$sel_bg" ] || abort "incomplete colors.toml for '$name'"
  for i in {0..15}; do
    [ -n "${pal[$i]}" ] || abort "incomplete colors.toml for '$name' (missing color$i)"
  done

  tmp="$out.tmp.$$"
  rm -rf "$tmp"
  mkdir -p "$tmp"

  {
    printf '# %s - Ghostty colors generated from Omarchy colors.toml.\n' "$title"
    printf 'background = %s\n' "$bg"
    printf 'foreground = %s\n' "$fg"
    printf 'cursor-color = %s\n' "$cursor"
    printf 'selection-background = %s\n' "$sel_bg"
    printf 'selection-foreground = %s\n' "$sel_fg"
    for i in {0..15}; do printf 'palette = %s=#%s\n' "$i" "${pal[$i]}"; done
  } > "$tmp/ghostty"

  cat > "$tmp/sketchybar" <<EOF
# $title - SketchyBar palette generated from Omarchy colors.toml.
export BAR_COLOR=0xff$bg
export LABEL_COLOR=0xff$fg
export ACCENT=0xff$accent
export MUTED=0xff${pal[8]}   # dimmed inactive workspace numbers
EOF

  cat > "$tmp/borders" <<EOF
# $title - JankyBorders palette generated from Omarchy colors.toml.
export ACTIVE_BORDER=0xff$accent
export INACTIVE_BORDER=0xff$sel_bg
EOF

  palette="${name//-/_}"
  arrow="$(printf '\342\236\234')"
  cat > "$tmp/starship" <<EOF
# $title - Starship prompt generated from Omarchy colors.toml.
"\$schema" = 'https://starship.rs/config-schema.json'
add_newline = true
palette = '$palette'
format = '\$directory\$git_branch\$git_status\$nodejs\$python\$character'

[palettes.$palette]
blue = '#${pal[4]}'
green = '#${pal[2]}'
red = '#${pal[1]}'
mauve = '#${pal[5]}'
yellow = '#${pal[3]}'

[directory]
style = 'bold blue'
truncation_length = 3
truncate_to_repo = true

[git_branch]
symbol = ' '
style = 'bold mauve'

[git_status]
style = 'bold red'

[nodejs]
symbol = ' '
style = 'green'

[python]
symbol = ' '
style = 'yellow'

[character]
success_symbol = '[$arrow](bold green)'
error_symbol = '[$arrow](bold red)'
EOF

  cat > "$tmp/btop" <<EOF
# $title - btop theme generated from Omarchy colors.toml.
theme[main_bg]="#$bg"
theme[main_fg]="#$fg"
theme[title]="#$fg"
theme[hi_fg]="#$accent"
theme[selected_bg]="#$sel_bg"
theme[selected_fg]="#$accent"
theme[inactive_fg]="#${pal[8]}"
theme[graph_text]="#${pal[8]}"
theme[meter_bg]="#$sel_bg"
theme[proc_misc]="#${pal[13]}"
theme[cpu_box]="#$accent"
theme[mem_box]="#${pal[2]}"
theme[net_box]="#${pal[3]}"
theme[proc_box]="#${pal[4]}"
theme[div_line]="#${pal[8]}"
theme[temp_start]="#${pal[2]}"
theme[temp_mid]="#${pal[3]}"
theme[temp_end]="#${pal[1]}"
theme[cpu_start]="#${pal[2]}"
theme[cpu_mid]="#${pal[3]}"
theme[cpu_end]="#${pal[1]}"
theme[free_start]="#${pal[4]}"
theme[free_mid]="#${pal[6]}"
theme[free_end]="#${pal[14]}"
theme[cached_start]="#${pal[6]}"
theme[cached_mid]="#${pal[12]}"
theme[cached_end]="#${pal[4]}"
theme[available_start]="#${pal[3]}"
theme[available_mid]="#${pal[9]}"
theme[available_end]="#${pal[1]}"
theme[used_start]="#${pal[2]}"
theme[used_mid]="#${pal[10]}"
theme[used_end]="#${pal[6]}"
theme[download_start]="#$accent"
theme[download_mid]="#${pal[13]}"
theme[download_end]="#${pal[5]}"
theme[upload_start]="#${pal[2]}"
theme[upload_mid]="#${pal[10]}"
theme[upload_end]="#${pal[4]}"
theme[process_start]="#$accent"
theme[process_mid]="#${pal[13]}"
theme[process_end]="#${pal[5]}"
EOF

  cat > "$tmp/nvim.lua" <<EOF
-- $title - Neovim colorscheme generated from the Omacase theme manifest.
return "$nvim"
EOF

  rm -rf "$out"
  mv "$tmp" "$out"
}

_theme_background_dir() {
  local name="$1"
  if [ "$(_theme_source "$name")" = local ]; then
    printf '%s/themes/%s\n' "$OMACASE_ROOT" "$name"
  else
    printf '%s/backgrounds/%s\n' "$OMACASE_DATA" "$name"
  fi
}

_theme_backgrounds() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | sort
}

_theme_fetch_omarchy_backgrounds() {
  local name="$1" mode="${2:-first}" upstream cache ref files file tmp downloaded=0
  [ "$(_theme_source "$name")" = omarchy ] || return 1
  have curl || return 1
  upstream="$(_omarchy_name "$name")"
  cache="$OMACASE_DATA/backgrounds/$name"
  ref="${OMACASE_OMARCHY_REF:-master}"
  mkdir -p "$cache"

  files="$(curl -fsSL "https://api.github.com/repos/basecamp/omarchy/contents/themes/$upstream/backgrounds?ref=$ref" 2>/dev/null \
    | grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/' \
    | grep -iE '\.(jpg|jpeg|png)$' | grep -ivE '^omarchy\.' | sort)" || true
  [ -n "$files" ] || return 1

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ -s "$cache/$file" ] && { downloaded=1; [ "$mode" = first ] && break; continue; }
    tmp="$cache/$file.tmp.$$"
    if curl -fsSL "https://raw.githubusercontent.com/basecamp/omarchy/$ref/themes/$upstream/backgrounds/$file" \
        -o "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      mv "$tmp" "$cache/$file"
      downloaded=1
      [ "$mode" = first ] && break
    else
      rm -f "$tmp"
    fi
  done <<< "$files"
  [ "$downloaded" -eq 1 ]
}

_theme_ensure_backgrounds() {
  local name="$1" dir
  dir="$(_theme_background_dir "$name")"
  [ -n "$(_theme_backgrounds "$dir")" ] && return 0
  [ "$(_theme_source "$name")" = omarchy ] || return 1
  is_dryrun && { printf '\033[2m[dry-run]\033[0m fetch wallpapers for %s\n' "$name"; return 0; }
  _theme_fetch_omarchy_backgrounds "$name" all
}

# Set the desktop wallpaper for the theme. Cached Omarchy backgrounds live under
# $OMACASE_DATA/backgrounds/<theme>/; custom local themes may still ship their
# own backgrounds. Failures degrade to a warning.
_theme_wallpaper() {
  local name="$1" dir img="" chosen
  dir="$(_theme_background_dir "$name")"
  chosen="$(cat "$OMACASE_STATE/wallpaper" 2>/dev/null || echo)"

  if [ -n "$chosen" ] && [ -f "$dir/$chosen" ]; then
    img="$dir/$chosen"
  else
    img="$(_theme_backgrounds "$dir" | head -1)" || true
  fi

  if [ -z "$img" ] && [ "$(_theme_source "$name")" = omarchy ]; then
    if is_dryrun; then
      printf '\033[2m[dry-run]\033[0m fetch+set wallpaper for %s\n' "$name"
      return 0
    fi
    if _theme_fetch_omarchy_backgrounds "$name" first; then
      img="$(_theme_backgrounds "$dir" | head -1)" || true
    else
      info "No wallpaper available for $name (skipped)."
      return 0
    fi
  fi

  [ -n "$img" ] || return 0
  _set_desktop_picture "$img" "$name"
}

# Set the desktop picture to $1 (per-theme subdir $2 for staging). macOS caches
# the desktop picture by PATH: setting a path it already shows won't refresh even
# after the file's bytes change. Stage a copy named by source stem + mtime, so
# any content change OR a switch to a different image is a NEW path macOS picks
# up. Best-effort; dry-run safe.
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
  if osascript -e "tell application \"System Events\" to set picture of every desktop to $(applescript_string "$live")" >/dev/null 2>&1; then
    info "Wallpaper → $(basename "$live")"
  else
    warn "Couldn't set wallpaper (grant Automation → System Events to your terminal)."
  fi
}

# `omacase wallpaper [list|next|prev|<n>]` — choose among the active theme's
# backgrounds. The choice persists in $OMACASE_STATE/wallpaper by basename.
omacase_wallpaper() {
  ensure_brew_env
  local theme dir bgs count cur idx chosen=""
  theme="$(cat "$OMACASE_STATE/theme" 2>/dev/null || echo)"
  [ -n "$theme" ] || abort "no active theme — run \`omacase theme\` first."
  _theme_known "$theme" || abort "unknown active theme '$theme'"

  _theme_ensure_backgrounds "$theme" || true
  dir="$(_theme_background_dir "$theme")"
  bgs="$(_theme_backgrounds "$dir" | sed "s#^$dir/##")"
  [ -n "$bgs" ] || abort "theme '$theme' has no backgrounds."
  count="$(printf '%s\n' "$bgs" | grep -c .)"

  cur="$(cat "$OMACASE_STATE/wallpaper" 2>/dev/null || echo)"
  printf '%s\n' "$bgs" | grep -qxF "$cur" || cur="$(printf '%s\n' "$bgs" | head -1)"
  idx="$(printf '%s\n' "$bgs" | grep -nxF "$cur" | head -1 | cut -d: -f1)"; idx=$((idx - 1))

  case "${1:-list}" in
    list|"")
      info "Backgrounds for '$theme' (● = current):"
      printf '%s\n' "$bgs" | awk -v c="$cur" '{printf "  %s %s\n", ($0==c?"\xe2\x97\x8f":" "), $0}'
      return 0 ;;
    pick)
      [ "$count" -gt 1 ] || { info "Only one background available for '$theme'."; return 0; }
      chosen="$(gum_choose "Wallpaper · $theme" $bgs)" || return 0 ;;
    next) chosen="$(printf '%s\n' "$bgs" | sed -n "$(( (idx + 1) % count + 1 ))p")" ;;
    prev) chosen="$(printf '%s\n' "$bgs" | sed -n "$(( (idx - 1 + count) % count + 1 ))p")" ;;
    [1-9]*) local n=$(( $1 - 1 )); { [ "$n" -ge 0 ] && [ "$n" -lt "$count" ]; } || abort "pick 1-$count"
            chosen="$(printf '%s\n' "$bgs" | sed -n "$((n + 1))p")" ;;
    *) abort "usage: omacase wallpaper [list|next|prev|pick|<n>]" ;;
  esac

  [ -n "$chosen" ] || return 0
  if ! is_dryrun; then
    ensure_state_dir
    echo "$chosen" > "$OMACASE_STATE/wallpaper"
  fi
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

_theme_list() {
  awk -F'|' '$0 !~ /^#/ && NF >= 5 { print $1 }' "$_THEME_MANIFEST" 2>/dev/null
}

# Light vs dark is derived from the theme's SketchyBar BAR_COLOR (0xffRRGGBB)
# using perceived luminance, so it stays correct for every theme with no
# per-theme flag to maintain. Returns 0 (true) when the background is light.
_theme_is_light() {
  local dir f hex
  dir="$(_theme_materialize "$1" 2>/dev/null)" || return 1
  f="$dir/sketchybar"
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
  pgrep -x sketchybar >/dev/null 2>&1 && run sketchybar --reload || true
  pgrep -x borders   >/dev/null 2>&1 && run brew services restart splaice/formulae/borders 2>/dev/null || true
  # Ghostty reloads its config (and the theme include) on SIGUSR2 since 1.2,
  # which also refreshes ANSI-palette CLIs like eza/ls. CAUTION: any OTHER
  # signal makes Ghostty quit. macOS truncates `comm` and hides GUI argv from
  # pgrep, so find the GUI process precisely via ps: args is exactly the binary
  # path with no extra args (NF==2), which excludes `ghostty +cmd` CLI runs.
  local gpid
  gpid="$(ps -Axo pid=,args= 2>/dev/null | awk '$2=="/Applications/Ghostty.app/Contents/MacOS/ghostty" && NF==2 {print $1}' || true)"
  [ -n "$gpid" ] && run kill -USR2 $gpid || true
  # nvim picks up the theme on next launch or via its own reload bind.
}
