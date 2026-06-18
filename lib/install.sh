# shellcheck shell=bash
# `omacase install` — the idempotent setup engine. Safe to re-run; it is the
# same engine `omacase update` calls. Omacase owns its dotfiles via symlinks
# (no chezmoi), and snapshots anything it would overwrite first.

omacase_install() {
  ensure_brew_env
  dryrun_banner
  source "$OMACASE_ROOT/lib/backup.sh"

  step "1/10  Packages & apps (brew bundle)"
  _sync_local_tap || warn "Local tap sync failed; borders may be stock."
  # NO_REQUIRE_TAP_TRUST: Homebrew gates third-party taps behind a trust prompt.
  # Omacase documents its curated taps and scopes this bypass to this command.
  run env HOMEBREW_NO_REQUIRE_TAP_TRUST=1 brew bundle --file="$OMACASE_ROOT/Brewfile" \
    || warn "Some brew items failed; re-run later."

  step "2/10  Link \`omacase\` onto PATH + shell completion"
  _link_command

  step "3/10  Safety backup (so this is reversible)"
  _auto_backup

  step "4/10  Dotfiles (symlinks)"
  _link_dotfiles

  step "5/10  Tool runtimes (mise: node + fast-moving npm CLIs)"
  _mise_install

  step "6/10  macOS defaults"
  bash "$OMACASE_ROOT/macos/defaults.sh"   # honors OMACASE_DRYRUN itself

  step "7/10  Theme"
  source "$OMACASE_ROOT/lib/theme.sh"
  omacase_theme "$(cat "$OMACASE_STATE/theme" 2>/dev/null || echo catppuccin-mocha)"
  # Theme switching flips macOS Light/Dark; that needs Automation consent, which
  # the line above just prompted for on a fresh machine. Flag it if still blocked.
  is_dryrun || can_set_appearance || \
    warn "Grant your terminal Automation → System Events so themes can sync macOS Light/Dark (\`omacase doctor\` re-checks)."

  step "8/10  Window manager + services"
  check_loop_conflict || true   # Loop fights AeroSpace; offer to quit it first
  source "$OMACASE_ROOT/lib/wm.sh"
  omacase_wm "$(cat "$OMACASE_STATE/wm" 2>/dev/null || echo aerospace)"

  step "9/10  Spotlight launchers (web apps + appearance toggle)"
  source "$OMACASE_ROOT/lib/actions.sh"
  omacase_launchers build || warn "Some launchers failed; re-run with \`omacase launchers build\`."

  step "10/10  Launch desktop apps (triggers their permission prompts)"
  _launch_apps

  step "Done"
  success "omacase installed."
  warn "Next: run \`omacase doctor\` and grant Accessibility to AeroSpace, SketchyBar & Karabiner"
  warn "  (plus Automation → System Events so themes can sync macOS Light/Dark)."
  warn "macOS requires those grants by hand — no installer can click them for you."
  warn "Don't like the result? \`omacase restore\` rolls back to the pre-install snapshot."
}

# Install the tools declared in ~/.config/mise/config.toml (node + the npm: CLIs
# that ship faster on npm than Homebrew). Idempotent — converges to the config.
# mise is provided by `brew bundle` and activated in dot_zshrc.
_mise_install() {
  have mise || { warn "mise not found (brew bundle should install it) — skipping npm CLIs."; return 0; }
  run mise install -y || warn "mise install had issues — re-run \`mise install\` later."
}

# Omacase ships a patched JankyBorders (adds `square_apps=` for square-cornered
# apps like undecorated Ghostty) as formula/borders.rb, built from the
# splaice/JankyBorders fork. It's served from a machine-local tap so brew
# treats it like any other package (`brew services start splaice/formulae/borders` etc.).
# Drop back to FelixKratz/formulae/borders in the Brewfile if upstream merges it.
_sync_local_tap() {
  local tap_dir; tap_dir="$(brew --repository)/Library/Taps/splaice/homebrew-formulae"
  [ -d "$tap_dir/Formula" ] || run brew tap-new splaice/formulae --no-git
  run cp "$OMACASE_ROOT/formula/borders.rb" "$tap_dir/Formula/borders.rb"
  run brew trust splaice/formulae >/dev/null 2>&1 || true  # newer brews gate taps

  # Converge to the formula's pinned version. HOMEBREW_NO_REQUIRE_TAP_TRUST is
  # scoped to this one command: brew's tap-trust check (as of mid-2026) aborts
  # source builds whenever ANY untrusted tap exists, even unrelated ones.
  local want have
  want="$(sed -n 's/^ *version "\(.*\)"$/\1/p' "$OMACASE_ROOT/formula/borders.rb")"
  have="$(brew list --versions borders 2>/dev/null | awk '{print $2}')"
  if [ -z "$have" ]; then
    run env HOMEBREW_NO_REQUIRE_TAP_TRUST=1 brew install splaice/formulae/borders
  elif [ "$have" != "$want" ]; then
    run env HOMEBREW_NO_REQUIRE_TAP_TRUST=1 brew reinstall splaice/formulae/borders
  fi
}

# Make `omacase` available on PATH for every shell (zsh/bash/fish) and for GUI
# contexts, by symlinking it into Apple Silicon Homebrew's bin.
# This is what `brew link` does for formulae; idempotent via `ln -sfn`.
_link_command() {
  local bindir; bindir="$(_omacase_bindir)"
  if [ -z "$bindir" ]; then
    warn "No Homebrew bin dir found; \`omacase\` stays available via ~/.zshrc only."
    return 0
  fi
  run ln -sfn "$OMACASE_ROOT/bin/omacase" "$bindir/omacase"
  is_dryrun || success "omacase → $bindir/omacase"

  # Tab completion: link _omacase next to Homebrew's other completions.
  # Group-writable dirs anywhere above an fpath entry make compinit prompt
  # "insecure directories?" on every new shell, so strip go-w on the whole
  # chain (Homebrew's documented fix; brew installs can re-add it to share/).
  local zfunc; zfunc="$(_omacase_zfuncdir)"
  local share="${zfunc%/zsh/site-functions}"
  run mkdir -p "$zfunc"
  run ln -sfn "$OMACASE_ROOT/completions/_omacase" "$zfunc/_omacase"
  run chmod go-w "$share" "$share/zsh" "$zfunc" "$share/zsh-completions" 2>/dev/null || true
  is_dryrun || success "completion → $zfunc/_omacase"
}

# GUI helpers that must be running (and granted permissions) for the system to
# work: Karabiner mints the Super key. The launcher is Spotlight (a system
# service, nothing to launch). open -a is a no-op if already running.
_launch_apps() {
  local app
  for app in "Karabiner-Elements"; do
    [ -d "/Applications/$app.app" ] && run open -a "$app" || true
  done
  # Karabiner 15+ ships its virtual HID as a DriverKit system extension. Merely
  # opening the app does NOT surface the approval prompt — explicitly asking the
  # bundled VirtualHIDDevice-Manager to `activate` does (macOS then shows the
  # system-extension prompt → Login Items & Extensions). The user still approves
  # by hand, but at least the dialog now appears during install.
  local km="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
  [ -x "$km" ] && run "$km" activate || true
  warn "Karabiner needs Input Monitoring + its driver extension enabled — a by-hand"
  warn "grant. \`omacase doctor\` lists what's left."
}

# Symlink every file under home/ into $HOME, translating chezmoi-style dot_
# prefixes (dot_zshrc → ~/.zshrc, dot_config/x → ~/.config/x). Pre-existing
# real config at a managed target is removed only AFTER _auto_backup saved it.
# Leaf-file granularity lets theme symlinks (e.g. nvim/lua/theme.lua) live
# alongside without polluting the repo.
_link_dotfiles() {
  source "$OMACASE_ROOT/lib/backup.sh"
  # Clear pre-existing real config at managed targets (already backed up).
  local t
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if ! _is_omacase_link "$t" && { [ -e "$t" ] || [ -L "$t" ]; }; then
      run rm -rf "$t"
    fi
  done < <(_managed_targets)

  # Symlink each source file to its translated target.
  local src="$OMACASE_ROOT/home" f rel target
  while IFS= read -r f; do
    rel="${f#"$src"/}"
    target="$HOME/$(printf '%s' "$rel" | sed -e 's#^dot_#.#' -e 's#/dot_#/.#g')"
    run mkdir -p "$(dirname "$target")"
    run ln -sfn "$f" "$target"
  done < <(find "$src" -type f ! -name '.DS_Store')
}

omacase_uninstall() {
  source "$OMACASE_ROOT/lib/backup.sh"
  warn "This removes Omacase-managed symlinks & stops its services."
  warn "It does NOT uninstall your Homebrew apps."
  is_dryrun || confirm "Proceed?" || { info "Cancelled."; return; }
  source "$OMACASE_ROOT/lib/wm.sh"; _wm_stop_all || true

  # Remove only the symlinks Omacase created.
  local src="$OMACASE_ROOT/home" f rel target
  while IFS= read -r f; do
    rel="${f#"$src"/}"
    target="$HOME/$(printf '%s' "$rel" | sed -e 's#^dot_#.#' -e 's#/dot_#/.#g')"
    _is_omacase_link "$target" && run rm -f "$target"
  done < <(find "$src" -type f ! -name '.DS_Store')

  # Theme symlinks are created by `omacase theme`, not from home/.
  local themed
  for themed in "$HOME/.config/ghostty/theme" \
                "$HOME/.config/sketchybar/theme.sh" \
                "$HOME/.config/borders/theme.conf" \
                "$HOME/.config/btop/themes/current.theme" \
                "$HOME/.config/nvim/lua/theme.lua" \
                "$HOME/.config/starship/theme.toml"; do
    _is_omacase_link "$themed" && run rm -f "$themed"
  done

  # Runtime helper scripts generated by the SketchyBar config.
  local generated
  for generated in "$HOME/.config/sketchybar/spaces.sh" \
                   "$HOME/.config/sketchybar/space_handler.sh" \
                   "$HOME/.config/sketchybar/sysstats.sh" \
                   "$HOME/.config/btop/omacase-popup.conf"; do
    [ -e "$generated" ] || [ -L "$generated" ] || continue
    run rm -f "$generated"
  done

  source "$OMACASE_ROOT/lib/actions.sh"
  _launchers_remove "$HOME/Applications"

  # Remove the `omacase` command + completion symlinks from Homebrew (only ours).
  local cmd
  for cmd in /opt/homebrew/bin/omacase /opt/homebrew/share/zsh/site-functions/_omacase; do
    _is_omacase_link "$cmd" && run rm -f "$cmd"
  done

  success "Omacase symlinks and generated artifacts removed."
  log "To bring back your original config: omacase restore   (see: omacase restore --list)"
}
