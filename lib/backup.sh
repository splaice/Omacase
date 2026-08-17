# shellcheck shell=bash
# Backup & restore — Omacase snapshots any pre-existing state it is about to
# overwrite (dotfiles + mutable OmniWM settings + macOS defaults) so a run is
# always reversible.
#
#   omacase backup [label]     create a snapshot now
#   omacase restore [id]       restore a snapshot (default: most recent)
#   omacase restore --list     list snapshots
#
# Snapshots live in $OMACASE_STATE/backups/<id>/ :
#   meta            label, version, host, date
#   manifest        one line per managed leaf file: "PRESENT|ABSENT <rel>"
#   files/<rel>     copies of pre-existing leaf files (relative to $HOME)
#   defaults/*.plist  exported macOS defaults domains

OMACASE_BACKUPS="$OMACASE_STATE/backups"

# macOS defaults domains touched by macos/defaults.sh — kept in sync with it.
OMACASE_DEFAULTS_DOMAINS=(
  NSGlobalDomain
  com.apple.finder
  com.apple.desktopservices
  com.apple.dock
  com.apple.spaces
  com.apple.WindowManager
  com.apple.screencapture
  com.apple.AppleMultitouchTrackpad
  com.apple.driver.AppleBluetoothMultitouch.trackpad
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

# Individual file targets linked from home/. Used to tell a real collision from
# an unrelated file that merely lives beside Omacase config in the same app
# directory.
_managed_file_targets() {
  local src="$OMACASE_ROOT/home" f rel
  while IFS= read -r f; do
    rel="${f#"$src"/}"
    printf '%s/%s\n' "$HOME" \
      "$(printf '%s' "$rel" | sed -e 's#^dot_#.#' -e 's#/dot_#/.#g')"
  done < <(find "$src" -type f ! -name '.DS_Store' ! -name '*.pyc' ! -path '*/__pycache__/*')
}

_managed_theme_targets() {
  printf '%s\n' \
    "$HOME/.config/ghostty/theme" \
    "$HOME/.config/omacase/theme.sh" \
    "$HOME/.config/btop/themes/current.theme" \
    "$HOME/.config/nvim/lua/theme.lua" \
    "$HOME/.config/starship/theme.toml"
}

# Snapshot the exact leaf files Omacase links, plus generated theme fragments
# and seeded-once user config (OmniWM settings, login-items).
_backup_targets() {
  _managed_file_targets
  _managed_theme_targets
  echo "$HOME/.config/omniwm/settings.toml"
  echo "$HOME/.config/omacase/login-items"
}

# Restore manifests created by earlier Omacase releases can contain top-level
# paths that the current release no longer manages. Keep this exact allowlist
# separate from _backup_targets: new snapshots should not capture these paths,
# but old snapshots must remain restorable after an upgrade.
_legacy_restore_targets() {
  printf '%s\n' \
    "$HOME/.config/aerospace" \
    "$HOME/.config/borders" \
    "$HOME/.config/karabiner" \
    "$HOME/.config/sketchybar"
}

# True if $1 or any ancestor (up to $HOME) is our link. Old-style installs
# symlinked whole ~/.config/<app> dirs into the repo; leaves under such a
# link hold nothing of the user's.
_under_omacase_link() {
  local p="$1"
  while [ "$p" != "$HOME" ] && [ "$p" != "/" ]; do
    _is_omacase_link "$p" && return 0
    p="$(dirname "$p")"
  done
  return 1
}

# --- backup ------------------------------------------------------------------
omacase_backup() {
  local label="${1:-manual}"
  local base id dest suffix=0
  base="$(date +%Y%m%d-%H%M%S)"
  id="$base"
  dest="$OMACASE_BACKUPS/$id"

  if is_dryrun; then
    info "Creating backup $id ($label)"
    log "[dry-run] would snapshot dotfiles + defaults into $dest"
    return 0
  fi
  local old_umask
  old_umask="$(umask)"
  umask 077
  mkdir -p "$OMACASE_BACKUPS"
  chmod 700 "$OMACASE_STATE" "$OMACASE_BACKUPS"
  while ! mkdir "$dest" 2>/dev/null; do
    suffix=$((suffix + 1))
    id="$base-$suffix"
    dest="$OMACASE_BACKUPS/$id"
  done
  info "Creating backup $id ($label)"
  mkdir "$dest/files" "$dest/defaults"
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
    if _under_omacase_link "$target"; then
      continue                                  # our own symlink — nothing of theirs to save
    elif [ -e "$target" ] || [ -L "$target" ]; then
      mkdir -p "$dest/files/$(dirname "$rel")"
      cp -RP "$target" "$dest/files/$rel"
      echo "PRESENT $rel" >> "$dest/manifest"
      n=$((n+1))
    else
      echo "ABSENT $rel" >> "$dest/manifest"    # record so restore can remove what we create
    fi
  done < <(_backup_targets)

  local d
  for d in "${OMACASE_DEFAULTS_DOMAINS[@]}"; do
    defaults export "$d" "$dest/defaults/$d.plist" 2>/dev/null || true
  done

  mkdir -p "$OMACASE_STATE"
  echo "$id" > "$OMACASE_STATE/last-backup"
  umask "$old_umask"
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
  # A top-level symlink must be replaced with a real directory before leaf
  # links are created, so snapshot it even if none of today's leaf names exist.
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    case "$t" in
      "$HOME/.config/"*)
        [ -L "$t" ] || continue
        omacase_backup pre-install
        return ;;
    esac
  done < <(_managed_targets)

  # Real app config directories are safe to keep. Back up only when a specific
  # file Omacase will replace is not already one of our links.
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if ! _is_omacase_link "$t" && { [ -e "$t" ] || [ -L "$t" ]; }; then
      omacase_backup pre-install
      return
    fi
  done < <(_managed_file_targets; _managed_theme_targets)
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
  done < <(_backup_targets; _managed_targets; _legacy_restore_targets)
  return 1
}

_rel_is_leaf_target() {
  local rel="$1" target managed_rel
  while IFS= read -r target; do
    managed_rel="${target#"$HOME"/}"
    [ "$rel" = "$managed_rel" ] && return 0
  done < <(_backup_targets)
  return 1
}

# rmdir upward from the deleted path's parent. Stops before $HOME/.config and
# $HOME; rmdir fails (and the walk stops) as soon as a sibling remains.
_prune_empty_parents() {
  local p
  p="$(dirname "$1")"
  while [ -n "$p" ] && [ "$p" != "/" ] && [ "$p" != "$HOME" ] && [ "$p" != "$HOME/.config" ]; do
    run rmdir "$p" 2>/dev/null || break
    p="$(dirname "$p")"
  done
}

_prune_empty_dirs_under() {
  local root="$1" p
  [ -d "$root" ] || return 0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ "$p" = "$root" ] && continue
    run rmdir "$p" 2>/dev/null || true
  done < <(find "$root" -depth -type d)
}

# Legacy v1 PRESENT directory: merge files back, never wipe the tree.
_restore_present_dir() {
  local dir="$1" rel="$2" target="$3"
  local saved dest sub p counterpart

  # Never merge through a symlink: an unrelated current link may point outside
  # $HOME, and writing $target/<subpath> would overwrite its destination.
  # Replacing the link itself restores the snapshot without touching that tree.
  if [ -L "$target" ] || { [ -e "$target" ] && [ ! -d "$target" ]; }; then
    run rm -f "$target"
  fi
  run mkdir -p "$target"

  while IFS= read -r saved; do
    [ -n "$saved" ] || continue
    sub="${saved#"$dir/files/$rel"/}"
    dest="$target/$sub"
    run rm -f "$dest"
    run mkdir -p "$(dirname "$dest")"
    run cp -RP "$saved" "$dest"
  done < <(find "$dir/files/$rel" \( -type f -o -type l \))

  if [ -d "$target" ]; then
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      _is_omacase_link "$p" || continue
      counterpart="$dir/files/$rel/${p#"$target"/}"
      if [ ! -e "$counterpart" ] && [ ! -L "$counterpart" ]; then
        run rm -f "$p"
      fi
    done < <(find "$target" -type l)
  fi

  _prune_empty_dirs_under "$target"
}

# Legacy v1 ABSENT directory: remove only what Omacase owns, then rmdir.
_restore_absent_toplevel() {
  local target="$1"
  local p leaf

  if [ -L "$target" ]; then
    if _is_omacase_link "$target"; then
      run rm -f "$target"
      _prune_empty_parents "$target"
    fi
    return
  fi

  if [ -d "$target" ]; then
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      _is_omacase_link "$p" && run rm -f "$p"
    done < <(find "$target" -type l)
  fi

  while IFS= read -r leaf; do
    [ -n "$leaf" ] || continue
    case "$leaf" in
      "$target"/*)
        run rm -f "$leaf"
        _prune_empty_parents "$leaf"
        ;;
    esac
  done < <(_backup_targets)

  _prune_empty_dirs_under "$target"
  run rmdir "$target" 2>/dev/null || true
  _prune_empty_parents "$target"
}

_valid_restore_rel() {
  local rel="$1"
  [ -n "$rel" ] || return 1
  case "$rel" in /*|*"/../"*|../*|*/..|..|*"/.") return 1 ;; esac
  _rel_is_managed_target "$rel"
}

_validate_restore_manifest() {
  local manifest="$1" files_root="$2" status rel extra source line=0
  [ -f "$manifest" ] || return 0
  while read -r status rel extra; do
    line=$((line + 1))
    [ -n "${status:-}" ] || continue
    [ -z "${extra:-}" ] || abort "Invalid backup manifest line $line: too many fields."
    case "$status" in PRESENT|ABSENT) ;; *) abort "Invalid backup manifest line $line: unknown status '$status'." ;; esac
    _valid_restore_rel "$rel" || abort "Invalid backup manifest line $line: unsafe path '$rel'."
    if [ "$status" = "PRESENT" ]; then
      source="$files_root/$rel"
      [ -e "$source" ] || [ -L "$source" ] || \
        abort "Invalid backup manifest line $line: saved file is missing for '$rel'."
    fi
  done < "$manifest"
}

_validate_restore_defaults() {
  local dir="$1" plist
  for plist in "$dir"/defaults/*.plist; do
    [ -e "$plist" ] || continue
    plutil -lint "$plist" >/dev/null 2>&1 || \
      abort "Invalid defaults snapshot: $(basename "$plist")."
  done
}

# --- restore -----------------------------------------------------------------
omacase_restore() {
  if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then _restore_list; return; fi
  local id="${1:-$(cat "$OMACASE_STATE/last-backup" 2>/dev/null)}"
  [ -n "$id" ] || abort "No backups found. (omacase restore --list)"
  _valid_backup_id "$id" || abort "Invalid backup id '$id'. (omacase restore --list)"
  local dir="$OMACASE_BACKUPS/$id"
  [ -d "$dir" ] || abort "No such backup '$id'. (omacase restore --list)"
  _validate_restore_manifest "$dir/manifest" "$dir/files"
  _validate_restore_defaults "$dir"

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
          if [ -d "$dir/files/$rel" ] && [ ! -L "$dir/files/$rel" ]; then
            _restore_present_dir "$dir" "$rel" "$target"
          else
            run rm -f "$target"
            run mkdir -p "$(dirname "$target")"
            run cp -RP "$dir/files/$rel" "$target"
          fi ;;
        ABSENT)
          if _rel_is_leaf_target "$rel"; then
            run rm -f "$target"
            _prune_empty_parents "$target"
          else
            _restore_absent_toplevel "$target"
          fi ;;
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
