# shellcheck shell=bash
# Backup & restore — Omacase snapshots any pre-existing state it is about to
# overwrite (dotfiles + macOS defaults) so a run is always reversible.
#
#   omacase backup [label]     create a snapshot now
#   omacase restore [id]       restore a snapshot (default: most recent)
#   omacase restore --list     list snapshots
#
# Snapshots live in $OMACASE_STATE/backups/<id>/ :
#   meta            label, version, host, date
#   manifest        one line per managed dotfile target: "PRESENT|ABSENT <rel>"
#   files/<rel>     copies of pre-existing dotfile targets (relative to $HOME)
#   defaults/*.plist  exported macOS defaults domains

OMACASE_BACKUPS="$OMACASE_STATE/backups"

# macOS defaults domains touched by macos/defaults.sh — kept in sync with it.
OMACASE_DEFAULTS_DOMAINS=(
  NSGlobalDomain
  com.apple.finder
  com.apple.desktopservices
  com.apple.dock
  com.apple.screencapture
  com.apple.AppleMultitouchTrackpad
)

# Top-level paths Omacase manages, derived from the home/ source tree.
# dot_zshrc → ~/.zshrc ; dot_config/<app> → ~/.config/<app>
_managed_targets() {
  ( cd "$OMACASE_ROOT/home" 2>/dev/null || return
    for e in dot_*; do
      [ -e "$e" ] || continue
      if [ "$e" = "dot_config" ]; then
        for a in dot_config/*; do echo "$HOME/.config/$(basename "$a")"; done
      else
        echo "$HOME/.${e#dot_}"
      fi
    done )
}

# True if PATH is a symlink that already points inside this repo or Omacase's
# generated theme cache.
_is_omacase_link() {
  local t="$1" dest
  [ -L "$t" ] || return 1
  dest="$(readlink "$t")"
  case "$dest" in
    "$OMACASE_ROOT"/*|"$OMACASE_DATA"/generated/themes/*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- backup ------------------------------------------------------------------
omacase_backup() {
  local label="${1:-manual}"
  local id; id="$(date +%Y%m%d-%H%M%S)"
  local dest="$OMACASE_BACKUPS/$id"

  info "Creating backup $id ($label)"
  if is_dryrun; then
    log "[dry-run] would snapshot dotfiles + defaults into $dest"
    return 0
  fi
  mkdir -p "$dest/files" "$dest/defaults"
  {
    echo "label=$label"
    echo "version=$(cat "$OMACASE_ROOT/VERSION" 2>/dev/null)"
    echo "host=$(hostname)"
    echo "date=$(date)"
  } > "$dest/meta"

  local n=0
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    local rel="${target#"$HOME"/}"
    if _is_omacase_link "$target"; then
      continue                                  # our own symlink — nothing of theirs to save
    elif [ -e "$target" ] || [ -L "$target" ]; then
      mkdir -p "$dest/files/$(dirname "$rel")"
      cp -RP "$target" "$dest/files/$rel"
      echo "PRESENT $rel" >> "$dest/manifest"
      n=$((n+1))
    else
      echo "ABSENT $rel" >> "$dest/manifest"    # record so restore can remove what we create
    fi
  done < <(_managed_targets)

  local d
  for d in "${OMACASE_DEFAULTS_DOMAINS[@]}"; do
    defaults export "$d" "$dest/defaults/$d.plist" 2>/dev/null || true
  done

  mkdir -p "$OMACASE_STATE"
  echo "$id" > "$OMACASE_STATE/last-backup"
  success "Backup $id saved ($n existing dotfile target(s) + ${#OMACASE_DEFAULTS_DOMAINS[@]} defaults domains)."
  log    "Restore anytime with:  omacase restore $id"
}

# Auto-backup before a destructive step. Always create a first snapshot so the
# macOS defaults layer is reversible on a clean machine; after that, only create
# a new snapshot when there is real non-Omacase dotfile state to lose.
_auto_backup() {
  if [ ! -f "$OMACASE_STATE/last-backup" ]; then
    omacase_backup pre-install
    return
  fi

  local t
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if ! _is_omacase_link "$t" && { [ -e "$t" ] || [ -L "$t" ]; }; then
      omacase_backup pre-install
      return
    fi
  done < <(_managed_targets)
  info "No pre-existing conflicting dotfiles — keeping existing backup."
}

_valid_backup_id() {
  case "$1" in ""|*/*|*..*) return 1 ;; *) return 0 ;; esac
}

_rel_is_managed_target() {
  local rel="$1" target managed_rel
  while IFS= read -r target; do
    managed_rel="${target#"$HOME"/}"
    [ "$rel" = "$managed_rel" ] && return 0
  done < <(_managed_targets)
  return 1
}

_valid_restore_rel() {
  local rel="$1"
  [ -n "$rel" ] || return 1
  case "$rel" in /*|*"/../"*|../*|*/..|..|*"/."|.*"/../"*) return 1 ;; esac
  _rel_is_managed_target "$rel"
}

_validate_restore_manifest() {
  local manifest="$1" status rel extra line=0
  [ -f "$manifest" ] || return 0
  while read -r status rel extra; do
    line=$((line + 1))
    [ -n "${status:-}" ] || continue
    [ -z "${extra:-}" ] || abort "Invalid backup manifest line $line: too many fields."
    case "$status" in PRESENT|ABSENT) ;; *) abort "Invalid backup manifest line $line: unknown status '$status'." ;; esac
    _valid_restore_rel "$rel" || abort "Invalid backup manifest line $line: unsafe path '$rel'."
  done < "$manifest"
}

# --- restore -----------------------------------------------------------------
omacase_restore() {
  if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then _restore_list; return; fi
  local id="${1:-$(cat "$OMACASE_STATE/last-backup" 2>/dev/null)}"
  [ -n "$id" ] || abort "No backups found. (omacase restore --list)"
  _valid_backup_id "$id" || abort "Invalid backup id '$id'. (omacase restore --list)"
  local dir="$OMACASE_BACKUPS/$id"
  [ -d "$dir" ] || abort "No such backup '$id'. (omacase restore --list)"
  _validate_restore_manifest "$dir/manifest"

  warn "Restoring backup $id ($(grep '^label=' "$dir/meta" 2>/dev/null | cut -d= -f2))."
  warn "This overwrites the current Omacase-managed dotfiles & defaults with the snapshot."
  is_dryrun || confirm "Proceed?" || { info "Cancelled."; return; }

  if [ -f "$dir/manifest" ]; then
    local status rel target
    while read -r status rel; do
      [ -n "$rel" ] || continue
      target="$HOME/$rel"
      case "$status" in
        PRESENT)
          run rm -rf "$target"
          run mkdir -p "$(dirname "$target")"
          run cp -RP "$dir/files/$rel" "$target" ;;
        ABSENT)
          run rm -rf "$target" ;;             # remove what Omacase created
      esac
    done < "$dir/manifest"
  fi

  local plist domain
  for plist in "$dir"/defaults/*.plist; do
    [ -e "$plist" ] || continue
    domain="$(basename "$plist" .plist)"
    run defaults import "$domain" "$plist"
  done
  for app in Dock Finder SystemUIServer; do run killall "$app" 2>/dev/null || true; done

  success "Restored backup $id. (Restart any open apps to pick up reverted config.)"
}

_restore_list() {
  if [ ! -d "$OMACASE_BACKUPS" ] || [ -z "$(ls -A "$OMACASE_BACKUPS" 2>/dev/null)" ]; then
    info "No backups yet."; return
  fi
  local last; last="$(cat "$OMACASE_STATE/last-backup" 2>/dev/null)"
  printf '%-18s %-12s %s\n' "ID" "LABEL" "DATE"
  local d id
  for d in "$OMACASE_BACKUPS"/*/; do
    id="$(basename "$d")"
    printf '%-18s %-12s %s%s\n' "$id" \
      "$(grep '^label=' "$d/meta" 2>/dev/null | cut -d= -f2)" \
      "$(grep '^date='  "$d/meta" 2>/dev/null | cut -d= -f2-)" \
      "$([ "$id" = "$last" ] && echo '  (latest)')"
  done
}
