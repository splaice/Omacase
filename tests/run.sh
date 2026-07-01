#!/bin/bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0

fail() {
  printf 'not ok - %s\n' "$1" >&2
  FAILURES=$((FAILURES + 1))
}

pass() {
  printf 'ok - %s\n' "$1"
}

run_test() {
  local name="$1"; shift
  if ( "$@" ); then pass "$name"; else fail "$name"; fi
}

test_shell_quote_round_trips() {
  local value="/tmp/Oma Case/bin/oma'case" quoted roundtrip
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  quoted="$(shell_quote "$value")"
  eval "roundtrip=$quoted"
  [ "$roundtrip" = "$value" ]
}

test_applescript_string_escapes_quotes() {
  local value='/tmp/Oma "Case"\bin' encoded
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  encoded="$(applescript_string "$value")"
  [ "$encoded" = '"/tmp/Oma \"Case\"\\bin"' ]
}

test_auto_backup_creates_first_snapshot() {
  local tmp
  tmp="$(mktemp -d)"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  OMACASE_ROOT="$ROOT"
  mkdir -p "$HOME"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/backup.sh"
  _auto_backup >/dev/null
  [ -s "$OMACASE_STATE/last-backup" ] && [ -d "$OMACASE_STATE/backups/$(cat "$OMACASE_STATE/last-backup")" ]
}

test_restore_rejects_unsafe_manifest() {
  local tmp id out
  tmp="$(mktemp -d)"
  id="20260101-000000"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  OMACASE_ROOT="$ROOT"
  mkdir -p "$HOME" "$OMACASE_STATE/backups/$id"
  printf 'label=test\n' > "$OMACASE_STATE/backups/$id/meta"
  printf 'ABSENT ../bad\n' > "$OMACASE_STATE/backups/$id/manifest"
  out="$tmp/out"
  (
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/backup.sh"
    omacase_restore "$id"
  ) >"$out" 2>&1
  [ $? -ne 0 ] && grep -q "unsafe path" "$out"
}

test_generated_theme_symlinks_are_owned() {
  local tmp target
  tmp="$(mktemp -d)"
  HOME="$tmp/home"
  OMACASE_ROOT="$tmp/root"
  OMACASE_DATA="$tmp/data"
  OMACASE_STATE="$tmp/state"
  mkdir -p "$OMACASE_DATA/generated/themes/nord" "$HOME/.config/ghostty"
  target="$HOME/.config/ghostty/theme"
  ln -s "$OMACASE_DATA/generated/themes/nord/ghostty" "$target"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/backup.sh"
  _is_omacase_link "$target"
}

test_dry_run_launchers_do_not_create_applications_dir() {
  local tmp
  tmp="$(mktemp -d)"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  OMACASE_ROOT="$ROOT"
  OMACASE_DRYRUN=1
  mkdir -p "$HOME"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/actions.sh"
  omacase_launchers build >/dev/null
  [ ! -e "$HOME/Applications" ] && [ ! -e "$OMACASE_STATE" ]
}

test_caffeinate_rejects_unowned_pid() {
  local tmp
  tmp="$(mktemp -d)"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  OMACASE_ROOT="$ROOT"
  mkdir -p "$HOME" "$OMACASE_STATE"
  printf '%s\n' "$$" > "$OMACASE_STATE/caffeinate.pid"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/actions.sh"
  ! _caffeinate_awake
}

test_update_fails_when_self_pull_fails() {
  local tmp out
  tmp="$(mktemp -d)"
  OMACASE_ROOT="$tmp/repo"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  mkdir -p "$OMACASE_ROOT/.git" "$HOME"
  out="$tmp/out"
  (
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/update.sh"
    omacase_update
  ) >"$out" 2>&1
  [ $? -ne 0 ] && grep -q "git pull failed" "$out"
}

test_backup_domains_cover_defaults_sh() {
  OMACASE_ROOT="$ROOT"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/backup.sh"
  # Every com.apple.* domain macos/defaults.sh touches must be restorable,
  # i.e. present in OMACASE_DEFAULTS_DOMAINS (NSGlobalDomain covers -g).
  local dom d found missing=""
  while IFS= read -r dom; do
    found=0
    for d in "${OMACASE_DEFAULTS_DOMAINS[@]}"; do
      [ "$d" = "$dom" ] && { found=1; break; }
    done
    [ "$found" -eq 1 ] || missing="$missing $dom"
  done < <(grep -oE 'com\.apple\.[A-Za-z0-9._]+[A-Za-z0-9]' "$ROOT/macos/defaults.sh" | sort -u)
  [ -z "$missing" ] || { printf 'not covered by OMACASE_DEFAULTS_DOMAINS:%s\n' "$missing" >&2; return 1; }
}

test_theme_manifest_lists_all_themes() {
  OMACASE_ROOT="$ROOT"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/theme.sh"
  local themes
  themes="$(_theme_list)"
  [ "$(printf '%s\n' "$themes" | grep -c .)" -eq 21 ] &&
    printf '%s\n' "$themes" | grep -qx catppuccin-mocha &&
    printf '%s\n' "$themes" | grep -qx techno-viking
}

test_theme_renderer_creates_fragments() {
  local tmp colors out
  tmp="$(mktemp -d)"
  colors="$tmp/colors.toml"
  out="$tmp/out"
  cat > "$colors" <<'EOF'
accent = "#112233"
cursor = "#445566"
foreground = "#ddeeff"
background = "#010203"
selection_foreground = "#aabbcc"
selection_background = "#334455"
color0 = "#000000"
color1 = "#111111"
color2 = "#222222"
color3 = "#333333"
color4 = "#444444"
color5 = "#555555"
color6 = "#666666"
color7 = "#777777"
color8 = "#888888"
color9 = "#999999"
color10 = "#aaaaaa"
color11 = "#bbbbbb"
color12 = "#cccccc"
color13 = "#dddddd"
color14 = "#eeeeee"
color15 = "#ffffff"
EOF
  OMACASE_ROOT="$ROOT"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/theme.sh"
  _theme_render_from_colors sample "Sample" "sample-nvim" "$colors" "$out"
  [ -s "$out/ghostty" ] &&
    [ -s "$out/sketchybar" ] &&
    [ -s "$out/borders" ] &&
    [ -s "$out/btop" ] &&
    [ -s "$out/starship" ] &&
    [ -s "$out/nvim.lua" ] &&
    grep -q 'background = 010203' "$out/ghostty" &&
    grep -q 'export ACCENT=0xff112233' "$out/sketchybar" &&
    grep -q 'return "sample-nvim"' "$out/nvim.lua"
}

run_test "shell_quote round-trips shell paths" test_shell_quote_round_trips
run_test "applescript_string escapes launcher paths" test_applescript_string_escapes_quotes
run_test "_auto_backup creates first restore point" test_auto_backup_creates_first_snapshot
run_test "restore rejects unsafe manifest paths" test_restore_rejects_unsafe_manifest
run_test "generated theme symlinks are owned" test_generated_theme_symlinks_are_owned
run_test "dry-run launchers do not create files" test_dry_run_launchers_do_not_create_applications_dir
run_test "caffeinate pid ownership is verified" test_caffeinate_rejects_unowned_pid
run_test "update fails on self-update failure" test_update_fails_when_self_pull_fails
run_test "backup domains cover macos/defaults.sh" test_backup_domains_cover_defaults_sh
run_test "theme manifest lists all themes" test_theme_manifest_lists_all_themes
run_test "theme renderer creates generated fragments" test_theme_renderer_creates_fragments

if [ "$FAILURES" -gt 0 ]; then
  printf '%s test(s) failed\n' "$FAILURES" >&2
  exit 1
fi
