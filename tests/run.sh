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
  local tmp mode
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
  mode="$(stat -f '%Lp' "$OMACASE_STATE" 2>/dev/null || stat -c '%a' "$OMACASE_STATE")"
  [ -s "$OMACASE_STATE/last-backup" ] &&
    [ -d "$OMACASE_STATE/backups/$(cat "$OMACASE_STATE/last-backup")" ] &&
    [ "$mode" = 700 ]
}

test_backups_created_same_second_have_unique_ids() {
  local tmp first second
  tmp="$(mktemp -d)"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  OMACASE_ROOT="$ROOT"
  mkdir -p "$HOME"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/backup.sh"
  omacase_backup first >/dev/null
  first="$(cat "$OMACASE_STATE/last-backup")"
  omacase_backup second >/dev/null
  second="$(cat "$OMACASE_STATE/last-backup")"
  [ "$first" != "$second" ] &&
    [ -d "$OMACASE_STATE/backups/$first" ] &&
    [ -d "$OMACASE_STATE/backups/$second" ]
}

test_auto_backup_ignores_owned_top_level_file_link() {
  local tmp old
  tmp="$(mktemp -d)"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  OMACASE_ROOT="$ROOT"
  OMACASE_DATA="$tmp/data"
  old="20000101-000000"
  mkdir -p "$HOME" "$OMACASE_STATE/backups/$old"
  ln -s "$ROOT/home/dot_zshrc" "$HOME/.zshrc"
  printf '%s\n' "$old" > "$OMACASE_STATE/last-backup"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/backup.sh"
  _auto_backup >/dev/null
  [ "$(cat "$OMACASE_STATE/last-backup")" = "$old" ]
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
  # shellcheck disable=SC2181 # status is intentionally captured after the subshell
  [ $? -ne 0 ] && grep -q "unsafe path" "$out"
}

test_restore_rejects_missing_saved_file_before_changes() {
  local tmp id out target
  tmp="$(mktemp -d)"
  id="20260101-000000"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  OMACASE_ROOT="$ROOT"
  target="$HOME/.config/omniwm/settings.toml"
  mkdir -p "$(dirname "$target")" "$OMACASE_STATE/backups/$id/files"
  printf 'current = true\n' > "$target"
  printf 'label=test\n' > "$OMACASE_STATE/backups/$id/meta"
  printf 'PRESENT .config/omniwm/settings.toml\n' > "$OMACASE_STATE/backups/$id/manifest"
  out="$tmp/out"
  (
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/backup.sh"
    omacase_restore "$id"
  ) >"$out" 2>&1
  # shellcheck disable=SC2181 # status is intentionally captured after the subshell
  [ $? -ne 0 ] &&
    grep -q "saved file is missing" "$out" &&
    grep -q "current = true" "$target"
}

test_restore_rejects_invalid_defaults_before_changes() {
  local tmp id out target saved
  tmp="$(mktemp -d)"
  id="20260101-000000"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  OMACASE_ROOT="$ROOT"
  target="$HOME/.config/omniwm/settings.toml"
  saved="$OMACASE_STATE/backups/$id/files/.config/omniwm/settings.toml"
  mkdir -p "$(dirname "$target")" "$(dirname "$saved")" \
    "$OMACASE_STATE/backups/$id/defaults"
  printf 'current = true\n' > "$target"
  printf 'saved = true\n' > "$saved"
  printf 'label=test\n' > "$OMACASE_STATE/backups/$id/meta"
  printf 'PRESENT .config/omniwm/settings.toml\n' > "$OMACASE_STATE/backups/$id/manifest"
  printf 'not a plist\n' > "$OMACASE_STATE/backups/$id/defaults/NSGlobalDomain.plist"
  out="$tmp/out"
  (
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/backup.sh"
    omacase_restore "$id"
  ) >"$out" 2>&1
  # shellcheck disable=SC2181 # status is intentionally captured after the subshell
  [ $? -ne 0 ] &&
    grep -q "Invalid defaults snapshot" "$out" &&
    grep -q "current = true" "$target"
}

test_restore_accepts_legacy_omacase_targets() {
  local tmp manifest
  tmp="$(mktemp -d)"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  OMACASE_ROOT="$ROOT"
  manifest="$tmp/manifest"
  mkdir -p "$HOME" "$tmp/files"
  printf 'ABSENT .config/aerospace\n' > "$manifest"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/backup.sh"
  _validate_restore_manifest "$manifest" "$tmp/files"
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

test_auto_backup_captures_conflicting_theme_fragment() {
  local tmp old new
  tmp="$(mktemp -d)"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  OMACASE_ROOT="$ROOT"
  OMACASE_DATA="$tmp/data"
  old="20000101-000000"
  mkdir -p "$HOME/.config/ghostty" "$OMACASE_STATE/backups/$old"
  printf '%s\n' "$old" > "$OMACASE_STATE/last-backup"
  printf 'user theme\n' > "$HOME/.config/ghostty/theme"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/backup.sh"
  _auto_backup >/dev/null
  new="$(cat "$OMACASE_STATE/last-backup")"
  [ "$new" != "$old" ] &&
    grep -q 'user theme' "$OMACASE_STATE/backups/$new/files/.config/ghostty/theme"
}

test_dotfile_reinstall_preserves_unmanaged_siblings() {
  local tmp custom
  tmp="$(mktemp -d)"
  HOME="$tmp/home"
  OMACASE_ROOT="$ROOT"
  OMACASE_STATE="$tmp/state"
  OMACASE_DATA="$tmp/data"
  custom="$HOME/.config/ghostty/private.conf"
  mkdir -p "$(dirname "$custom")"
  printf 'user-owned = true\n' > "$custom"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/install.sh"
  _link_dotfiles
  [ -f "$custom" ] &&
    grep -q 'user-owned = true' "$custom" &&
    [ -L "$HOME/.config/ghostty/config" ]
}

test_backup_captures_live_omniwm_settings() {
  local tmp id
  tmp="$(mktemp -d)"
  HOME="$tmp/home"
  OMACASE_STATE="$tmp/state"
  OMACASE_ROOT="$ROOT"
  mkdir -p "$HOME/.config/omniwm"
  printf 'ipcEnabled = true\n' > "$HOME/.config/omniwm/settings.toml"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/backup.sh"
  omacase_backup test >/dev/null
  id="$(cat "$OMACASE_STATE/last-backup")"
  cmp -s "$HOME/.config/omniwm/settings.toml" \
    "$OMACASE_STATE/backups/$id/files/.config/omniwm/settings.toml"
}

test_update_fails_when_self_pull_fails() {
  # omacase_update's ensure_brew_env aborts before the pull on anything but
  # Apple Silicon + /opt/homebrew — the abort message would satisfy the
  # negative check for the wrong reason, so skip elsewhere.
  if [ "$(uname -m)" != "arm64" ] || [ ! -x /opt/homebrew/bin/brew ]; then
    return 0
  fi
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
  # shellcheck disable=SC2181 # status is intentionally captured after the subshell
  [ $? -ne 0 ] && grep -q "git pull failed" "$out"
}

test_bootstrap_copies_are_identical() {
  # Both are live curl|bash entry points; boot.sh is the source of truth and
  # site/install must be an exact copy (see boot.sh header).
  cmp -s "$ROOT/boot.sh" "$ROOT/site/install"
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

test_stage_manager_is_disabled_by_defaults() {
  grep -qE 'defaults write com\.apple\.WindowManager GloballyEnabled -bool false' \
    "$ROOT/macos/defaults.sh"
}

test_brew_trust_is_scoped() {
  ! grep -q 'HOMEBREW_NO_REQUIRE_TAP_TRUST' "$ROOT/lib/install.sh" &&
    grep -q 'brew trust --cask BarutSRB/tap/omniwm' "$ROOT/lib/install.sh" &&
    grep -q 'brew trust --formula finbarr/tap/yolobox' "$ROOT/lib/install.sh"
}

test_grok_installer_requires_opt_in() {
  grep -q 'OMACASE_INSTALL_GROK' "$ROOT/lib/install.sh" &&
    grep -q "Skipping Grok CLI's unpinned upstream installer" "$ROOT/lib/install.sh"
}

test_herdr_is_declared_in_brewfile() {
  grep -qE '^brew "herdr"' "$ROOT/Brewfile"
}

# Every agent CLI Omacase ships must also get a herdr agent hook, or that agent
# shows up in herdr as an anonymous shell with no lifecycle state. The declared
# set is derived from where each CLI actually comes from (Brewfile / mise /
# opt-in installer), so dropping one of those without updating the hook loop —
# or vice versa — fails here.
test_herdr_hooks_cover_shipped_agents() {
  local hooked declared="" agent
  hooked="$(sed -n 's/^ *for agent in \(.*\); do$/\1/p' "$ROOT/lib/install.sh")"
  [ -n "$hooked" ] || return 1
  grep -q 'cask "codex"'    "$ROOT/Brewfile" && declared="$declared codex"
  grep -q 'brew "opencode"' "$ROOT/Brewfile" && declared="$declared opencode"
  grep -q 'pi-coding-agent' "$ROOT/home/dot_config/mise/config.toml" && declared="$declared pi"
  grep -q 'OMACASE_INSTALL_GROK' "$ROOT/lib/install.sh" && declared="$declared grok"
  # claude self-manages via its own installer, so it is never declared elsewhere.
  for agent in $declared claude; do
    case " $hooked " in *" $agent "*) ;; *) return 1 ;; esac
  done
  grep -q 'herdr integration install "\$agent"' "$ROOT/lib/install.sh"
}

# herdr installs and refreshes its own skill on first launch; Omacase must not
# write into or delete from ~/.agents/skills (it cannot prove ownership there —
# issue #3). Regression: no skill generation or removal code may come back.
test_herdr_skill_is_not_managed_by_omacase() {
  ! grep -rq 'herdr --skill' "$ROOT/lib" &&
    ! grep -rq '_HERDR_SKILL_HOSTS' "$ROOT/lib" &&
    ! grep -rq 'agents/skills/herdr" && run rm' "$ROOT/lib"
}

test_theme_manifest_lists_all_themes() {
  OMACASE_ROOT="$ROOT"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/theme.sh"
  local themes expected
  themes="$(_theme_list)"
  # Derive the count from the manifest so adding a theme doesn't break the suite.
  expected="$(awk -F'|' '$0 !~ /^#/ && NF >= 5' "$ROOT/themes/manifest" | grep -c .)"
  [ "$expected" -ge 2 ] &&
    [ "$(printf '%s\n' "$themes" | grep -c .)" -eq "$expected" ] &&
    printf '%s\n' "$themes" | grep -qx catppuccin-mocha &&
    printf '%s\n' "$themes" | grep -qx techno-viking
}

test_omniwm_seed_is_valid_and_has_nine_workspaces() {
  python3 - "$ROOT/config/omniwm/settings.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    config = tomllib.load(handle)
workspaces = config["workspaces"]
assert config["general"]["ipcEnabled"] is True
assert config["general"]["defaultLayoutType"] == "niri"
assert "appRules" not in config
assert [workspace["name"] for workspace in workspaces] == list("123456789")
assert len({workspace["id"] for workspace in workspaces}) == 9
PY
}

test_ghostty_windows_remain_manageable() {
  local config="$ROOT/home/dot_config/ghostty/config"
  grep -qE '^window-decoration[[:space:]]*=[[:space:]]*true$' "$config" &&
    grep -qE '^macos-titlebar-style[[:space:]]*=[[:space:]]*transparent$' "$config"
}

test_omniwm_focused_mode_matches_pid() {
  OMACASE_ROOT="$ROOT"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/wm.sh"
  omniwmctl() {
    printf '%s\n' '{"result":{"payload":{"windows":[{"pid":42,"isFocused":true,"mode":"floating"}]}}}'
  }
  [ "$(_wm_focused_mode_for_pid 42)" = floating ] &&
    [ -z "$(_wm_focused_mode_for_pid 7)" ]
}

test_wm_menu_and_palette_route_to_ipc() {
  OMACASE_ROOT="$ROOT"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/wm.sh"
  local calls=""
  ensure_brew_env() { :; }
  _wm_ipc_ready() { return 0; }
  omniwmctl() { calls="$calls $2"; }
  omacase_wm menu &&
    omacase_wm palette &&
    [ "$calls" = " open-menu-anywhere open-command-palette" ] &&
    ! ( omacase_wm bogus ) 2>/dev/null
}

test_cli_unknown_command_fails() {
  local out
  out="$(mktemp)"
  ! "$ROOT/bin/omacase" no-such-command >"$out" 2>&1 &&
    grep -q "unknown command" "$out"
}

test_cli_help_and_version() {
  "$ROOT/bin/omacase" help | grep -q "usage: omacase" &&
    [ "$("$ROOT/bin/omacase" version)" = "$(cat "$ROOT/VERSION")" ]
}

test_extras_in_usage_completion_and_menu() {
  "$ROOT/bin/omacase" help | grep -qE '^[[:space:]]+extras[[:space:]]' &&
    grep -q "'extras:" "$ROOT/completions/_omacase" &&
    grep -q 'sudo-touchid' "$ROOT/completions/_omacase" &&
    grep -q '"Extras"' "$ROOT/lib/menu.sh"
}

test_extras_list_reports_sudo_touchid_state() {
  "$ROOT/bin/omacase" extras list | grep -qE 'sudo-touchid[[:space:]]+\((on|off|partial)\)'
}

test_launcher_build_produces_valid_bundle() {
  local tmp
  tmp="$(mktemp -d)"
  (
    HOME="$tmp"
    OMACASE_ROOT="$ROOT"
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/launcher.sh"
    _launcher_build
  ) >/dev/null 2>&1 &&
    [ -x "$tmp/Applications/OmacaseLauncher.app/Contents/MacOS/OmacaseLauncher" ] &&
    plutil -lint -s "$tmp/Applications/OmacaseLauncher.app/Contents/Info.plist" &&
    plutil -lint -s "$tmp/Library/LaunchAgents/org.omacase.launcher.plist" &&
    grep -q "$tmp/Applications/OmacaseLauncher.app/Contents/MacOS/OmacaseLauncher" \
      "$tmp/Library/LaunchAgents/org.omacase.launcher.plist"
}

test_launcher_reads_login_items_config() {
  # The shipped config must list OmniWM, and the launcher script must consult it.
  grep -qx 'OmniWM' "$ROOT/home/dot_config/omacase/login-items" &&
    grep -q 'omacase/login-items' "$ROOT/assets/launcher/OmacaseLauncher.sh"
}

# Issue #4: a failed migration must halt the runner and keep the marker, so
# the documented retry-on-next-update behavior is real.
test_migrate_failure_keeps_marker() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/root/migrations"
  printf 'migrate() { false; }\n' > "$tmp/root/migrations/20990101-boom.sh"
  (
    OMACASE_ROOT="$ROOT"
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/migrate.sh"
    OMACASE_ROOT="$tmp/root"
    OMACASE_STATE="$tmp/state"
    ! omacase_migrate >/dev/null 2>&1 &&
      [ ! -s "$tmp/state/migrations-last" ]
  )
}

# Issue #2: a fresh install records the greatest migration shipped in its tree,
# so even a future-dated id cannot replay because of clock skew or time zones.
test_migrate_baseline_covers_shipped_history() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/root/migrations"
  printf 'migrate() { touch "%s/ran"; }\n' "$tmp" > "$tmp/root/migrations/20990101-present-at-install.sh"
  (
    OMACASE_ROOT="$ROOT"
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/migrate.sh"
    OMACASE_ROOT="$tmp/root"
    OMACASE_STATE="$tmp/state"
    _migrations_baseline
    [ "$(cat "$tmp/state/migrations-last")" = "20990101-present-at-install" ] || exit 1
    omacase_migrate >/dev/null 2>&1
    [ ! -e "$tmp/ran" ]
  )
}

test_migrate_empty_history_uses_squash_baseline() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/root/migrations"
  (
    OMACASE_ROOT="$ROOT"
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/migrate.sh"
    OMACASE_ROOT="$tmp/root"
    OMACASE_STATE="$tmp/state"
    _migrations_baseline
    [ "$(cat "$tmp/state/migrations-last")" = "$_MIGRATIONS_SQUASH_BASELINE" ]
  )
}

test_migrate_baseline_allows_newer_migration() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/root/migrations"
  printf 'migrate() { touch "%s/old-ran"; }\n' "$tmp" > "$tmp/root/migrations/20260817-present-at-install.sh"
  (
    OMACASE_ROOT="$ROOT"
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/migrate.sh"
    OMACASE_ROOT="$tmp/root"
    OMACASE_STATE="$tmp/state"
    _migrations_baseline
    printf 'migrate() { touch "%s/new-ran"; }\n' "$tmp" > "$tmp/root/migrations/20260818-added-later.sh"
    omacase_migrate >/dev/null 2>&1
    [ ! -e "$tmp/old-ran" ] && [ -e "$tmp/new-ran" ]
  )
}

test_migrate_dryrun_uses_in_memory_baseline() {
  local tmp out
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/root/migrations"
  printf 'migrate() { touch "%s/ran"; }\n' "$tmp" > "$tmp/root/migrations/20990101-present-at-install.sh"
  out="$tmp/out"
  (
    OMACASE_ROOT="$ROOT"
    # shellcheck source=/dev/null
    source "$ROOT/lib/common.sh"
    # shellcheck source=/dev/null
    source "$ROOT/lib/migrate.sh"
    OMACASE_ROOT="$tmp/root"
    OMACASE_STATE="$tmp/state"
    export OMACASE_DRYRUN=1
    _migrations_baseline
    [ ! -e "$tmp/state/migrations-last" ] || exit 1
    omacase_migrate
    [ ! -e "$tmp/ran" ]
  ) > "$out" 2>&1 && grep -q '20990101-present-at-install' "$out"
}

# Package presence does not prove ownership when a machine can skip releases.
# Keep the no-automatic-Homebrew-removal rule mechanically enforced.
test_migrations_never_auto_uninstall_homebrew_packages() {
  ! find "$ROOT/migrations" -type f -name '*.sh' -exec \
    grep -En 'brew[[:space:]]+(uninstall|remove|rm)|brew[[:space:]]+bundle[[:space:]]+cleanup' {} + | grep -q .
}

test_usage_wired_and_compiles() {
  "$ROOT/bin/omacase" help | grep -qE '^[[:space:]]+usage[[:space:]]' &&
    grep -q "'usage:" "$ROOT/completions/_omacase" &&
    grep -q "'usage-tracker\[" "$ROOT/completions/_omacase" &&
    "$ROOT/bin/omacase" extras list | grep -qE '^[[:space:]]+usage-tracker[[:space:]]+\((on|off)\)' &&
    python3 -m py_compile "$ROOT/lib/usage.py"
}

test_usage_renders_fixture_records() {
  local tmp out
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/usage"
  local today; today="$(date +%Y-%m-%d)"
  local agent
  for agent in claude codex grok; do
    printf '{"agent":"%s","name":"%s","days":{"%s":{"total":123456,"models":{"m1":123456}}},"limits":[{"label":"weekly","used_percent":42.0}],"collected_at":"now"}\n' \
      "$agent" "$agent" "$today" > "$tmp/usage/$agent.json"
  done
  out="$(OMACASE_STATE="$tmp" "$ROOT/bin/omacase" usage)" &&
    printf '%s' "$out" | grep -q '123.5K' &&
    printf '%s' "$out" | grep -q '42.0%' &&
    printf '%s' "$out" | grep -q '└'
}

# Issue #5: concurrent refreshes share the state dir; writes must never fail or
# publish partial JSON. The old fixed-tmp-name code fails this at Path.replace.
test_usage_concurrent_writes_are_safe() {
  local tmp
  tmp="$(mktemp -d)"
  OMACASE_STATE="$tmp" python3 - "$ROOT/lib/usage.py" <<'PY' || return 1
import importlib.util, json, multiprocessing, sys
spec = importlib.util.spec_from_file_location("usage", sys.argv[1])
usage = importlib.util.module_from_spec(spec); spec.loader.exec_module(usage)
usage.STATE_DIR.mkdir(parents=True, exist_ok=True)
def worker(n):
    for i in range(25):
        for agent in ("claude", "codex", "grok"):
            usage._write_record(agent, {"agent": agent, "worker": n, "i": i})
# stdin scripts cannot be re-exec'd under spawn (macOS default).
ctx = multiprocessing.get_context("fork")
procs = [ctx.Process(target=worker, args=(n,)) for n in range(4)]
[p.start() for p in procs]; [p.join() for p in procs]
assert all(p.exitcode == 0 for p in procs), "a concurrent writer crashed"
for agent in ("claude", "codex", "grok"):
    json.loads((usage.STATE_DIR / f"{agent}.json").read_text())  # complete JSON
assert not list(usage.STATE_DIR.glob(".*.tmp")), "tmp orphans left behind"
PY
}

test_extras_mole_is_declared_everywhere() {
  "$ROOT/bin/omacase" extras list | grep -qE '^[[:space:]]+mole[[:space:]]' &&
    grep -qE '^brew "mole"' "$ROOT/Brewfile" &&
    grep -q "'mole\[" "$ROOT/completions/_omacase"
}

test_extras_sudo_touchid_dry_run_wraps_all_mutations() {
  # Every root mutation must go through `run sudo`, so a dry run prints them
  # instead of executing; the sudoers content must also validate.
  local out
  out="$(OMACASE_DRYRUN=1 "$ROOT/bin/omacase" extras sudo-touchid on)" &&
    printf '%s\n' "$out" | grep -q '\[dry-run\].*sudo install .* /etc/sudoers.d/omacase' &&
    ! printf '%s\n' "$out" | grep -E '^\s*sudo ' >/dev/null
}

test_cli_keybinds_displays_reference() {
  local out
  out="$(mktemp)"
  "$ROOT/bin/omacase" keybinds > "$out" &&
    cmp -s "$ROOT/KEYBINDS.md" "$out" &&
    "$ROOT/bin/omacase" help | grep -qE '^[[:space:]]+keybinds[[:space:]]'
}

test_menu_lists_primary_commands_and_routes_keybinds() {
  local captured out item
  captured="$(mktemp)"
  out="$(mktemp)"
  OMACASE_ROOT="$ROOT"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/menu.sh"
  gum_choose() {
    shift
    printf '%s\n' "$@" > "$captured"
    printf '%s\n' "View keybinds"
  }
  omacase_menu > "$out" &&
    cmp -s "$ROOT/KEYBINDS.md" "$out" || return 1
  for item in \
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
    "Uninstall Omacase"
  do
    grep -Fxq "$item" "$captured" || return 1
  done
}

test_menu_lists_app_and_overlay_commands() {
  local captured item
  captured="$(mktemp)"
  OMACASE_ROOT="$ROOT"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/menu.sh"
  gum_choose() {
    local header="$1"
    shift
    if [ "$header" = "Omacase" ]; then
      printf '%s\n' "Apps and overlays"
    else
      printf '%s\n' "$@" > "$captured"
      printf '%s\n' "Back"
    fi
  }
  omacase_menu
  for item in \
    "New terminal" \
    "File manager" \
    "Browser" \
    "Spotify" \
    "Apple Music" \
    "Obsidian" \
    "1Password" \
    "Messages" \
    "Todoist"
  do
    grep -Fxq "$item" "$captured" || return 1
  done
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
    [ -s "$out/palette" ] &&
    [ -s "$out/btop" ] &&
    [ -s "$out/starship" ] &&
    [ -s "$out/nvim.lua" ] &&
    grep -q 'background = 010203' "$out/ghostty" &&
    grep -q 'export THEME_ACCENT="#112233"' "$out/palette" &&
    grep -q 'return "sample-nvim"' "$out/nvim.lua"
}

test_theme_accent_snaps_to_nearest_preset() {
  OMACASE_ROOT="$ROOT"
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/theme.sh"
  # Exact preset hits, off-lightness hues (mint → Green, magenta → Pink),
  # and greys of any lightness → Graphite.
  [ "$(_theme_accent_nearest 007aff)" = "4|Blue" ] &&
    [ "$(_theme_accent_nearest ff3b30)" = "0|Red" ] &&
    [ "$(_theme_accent_nearest 82fb9c)" = "3|Green" ] &&
    [ "$(_theme_accent_nearest f12eaf)" = "6|Pink" ] &&
    [ "$(_theme_accent_nearest ffffff)" = "-1|Graphite" ] &&
    [ "$(_theme_accent_nearest 303030)" = "-1|Graphite" ]
}

run_test "shell_quote round-trips shell paths" test_shell_quote_round_trips
run_test "applescript_string escapes embedded quotes" test_applescript_string_escapes_quotes
run_test "_auto_backup creates first restore point" test_auto_backup_creates_first_snapshot
run_test "same-second backups receive unique ids" test_backups_created_same_second_have_unique_ids
run_test "auto-backup ignores owned top-level file links" test_auto_backup_ignores_owned_top_level_file_link
run_test "restore rejects unsafe manifest paths" test_restore_rejects_unsafe_manifest
run_test "restore preflights missing saved files" test_restore_rejects_missing_saved_file_before_changes
run_test "restore preflights invalid defaults" test_restore_rejects_invalid_defaults_before_changes
run_test "restore accepts legacy Omacase targets" test_restore_accepts_legacy_omacase_targets
run_test "generated theme symlinks are owned" test_generated_theme_symlinks_are_owned
run_test "auto-backup captures conflicting theme fragments" test_auto_backup_captures_conflicting_theme_fragment
run_test "dotfile reinstall preserves unmanaged siblings" test_dotfile_reinstall_preserves_unmanaged_siblings
run_test "manual backup captures live OmniWM settings" test_backup_captures_live_omniwm_settings
run_test "update fails on self-update failure" test_update_fails_when_self_pull_fails
run_test "backup domains cover macos/defaults.sh" test_backup_domains_cover_defaults_sh
run_test "defaults disable Stage Manager" test_stage_manager_is_disabled_by_defaults
run_test "Homebrew trust is scoped to exact third-party packages" test_brew_trust_is_scoped
run_test "Grok installer requires explicit opt-in" test_grok_installer_requires_opt_in
run_test "herdr is declared in the Brewfile" test_herdr_is_declared_in_brewfile
run_test "herdr agent hooks cover shipped agent CLIs" test_herdr_hooks_cover_shipped_agents
run_test "herdr skill is left to herdr, not managed by omacase" test_herdr_skill_is_not_managed_by_omacase
run_test "site/install matches boot.sh" test_bootstrap_copies_are_identical
run_test "theme manifest lists all themes" test_theme_manifest_lists_all_themes
run_test "OmniWM seed is valid with nine workspaces" test_omniwm_seed_is_valid_and_has_nine_workspaces
run_test "Ghostty windows remain manageable by OmniWM" test_ghostty_windows_remain_manageable
run_test "OmniWM focused mode is matched by pid" test_omniwm_focused_mode_matches_pid
run_test "wm menu and palette route to omniwmctl" test_wm_menu_and_palette_route_to_ipc
run_test "cli rejects unknown commands" test_cli_unknown_command_fails
run_test "cli help and version work" test_cli_help_and_version
run_test "extras wired into usage, completion, and menu" test_extras_in_usage_completion_and_menu
run_test "extras list reports sudo-touchid state" test_extras_list_reports_sudo_touchid_state
run_test "extras mole is declared in list, Brewfile, and completion" test_extras_mole_is_declared_everywhere
run_test "failed migration halts runner and keeps marker" test_migrate_failure_keeps_marker
run_test "install baseline covers every shipped migration" test_migrate_baseline_covers_shipped_history
run_test "empty migration history uses squash baseline" test_migrate_empty_history_uses_squash_baseline
run_test "install baseline allows a newer migration" test_migrate_baseline_allows_newer_migration
run_test "migration dry run uses in-memory baseline" test_migrate_dryrun_uses_in_memory_baseline
run_test "migrations never auto-uninstall Homebrew packages" test_migrations_never_auto_uninstall_homebrew_packages
run_test "usage command wired and python compiles" test_usage_wired_and_compiles
run_test "usage renders fixture records" test_usage_renders_fixture_records
run_test "usage concurrent writes are safe" test_usage_concurrent_writes_are_safe
run_test "launcher build produces a valid bundle and agent" test_launcher_build_produces_valid_bundle
run_test "launcher reads the login-items config" test_launcher_reads_login_items_config
run_test "extras sudo-touchid dry run wraps all mutations" test_extras_sudo_touchid_dry_run_wraps_all_mutations
run_test "cli keybinds displays KEYBINDS.md" test_cli_keybinds_displays_reference
run_test "menu lists primary commands and opens keybinds" test_menu_lists_primary_commands_and_routes_keybinds
run_test "menu lists app and overlay commands" test_menu_lists_app_and_overlay_commands
run_test "theme renderer creates generated fragments" test_theme_renderer_creates_fragments
run_test "theme accent snaps to nearest macOS preset" test_theme_accent_snaps_to_nearest_preset

if [ "$FAILURES" -gt 0 ]; then
  printf '%s test(s) failed\n' "$FAILURES" >&2
  exit 1
fi
