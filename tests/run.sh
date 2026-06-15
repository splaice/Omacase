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

run_test "shell_quote round-trips shell paths" test_shell_quote_round_trips
run_test "applescript_string escapes launcher paths" test_applescript_string_escapes_quotes
run_test "_auto_backup creates first restore point" test_auto_backup_creates_first_snapshot
run_test "restore rejects unsafe manifest paths" test_restore_rejects_unsafe_manifest
run_test "dry-run launchers do not create files" test_dry_run_launchers_do_not_create_applications_dir
run_test "caffeinate pid ownership is verified" test_caffeinate_rejects_unowned_pid
run_test "update fails on self-update failure" test_update_fails_when_self_pull_fails

if [ "$FAILURES" -gt 0 ]; then
  printf '%s test(s) failed\n' "$FAILURES" >&2
  exit 1
fi
