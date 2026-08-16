# shellcheck shell=bash
# `omacase install` — the idempotent setup engine. Safe to re-run; it is the
# same engine `omacase update` calls. Omacase owns its dotfiles via symlinks
# (no chezmoi), and snapshots anything it would overwrite first.

omacase_install() {
  ensure_brew_env
  dryrun_banner
  source "$OMACASE_ROOT/lib/backup.sh"
  _preflight_command_links

  step "1/8  Packages & apps (brew bundle)"
  _brew_trust_declared_third_party
  run brew bundle --file="$OMACASE_ROOT/Brewfile" \
    || warn "Some brew items failed; re-run later."

  step "2/8  Link \`omacase\` onto PATH + shell completion"
  _link_command

  step "3/8  Safety backup (so this is reversible)"
  _auto_backup

  step "4/8  Dotfiles (symlinks)"
  _link_dotfiles

  step "5/8  Tool runtimes & AI CLIs (mise + optional grok) + herdr agent hooks & skill"
  _mise_install
  _grok_install
  _herdr_integrations
  _herdr_skill

  step "6/8  macOS defaults"
  bash "$OMACASE_ROOT/macos/defaults.sh"   # honors OMACASE_DRYRUN itself

  step "7/8  Theme"
  source "$OMACASE_ROOT/lib/theme.sh"
  # ${:-} (not `|| echo`): an existing-but-empty state file would otherwise
  # yield "" and drop a non-interactive install into the theme picker.
  local saved_theme; saved_theme="$(cat "$OMACASE_STATE/theme" 2>/dev/null || true)"
  OMACASE_BACKUP_READY=1 omacase_theme "${saved_theme:-catppuccin-mocha}"
  # Theme switching flips macOS Light/Dark; that needs Automation consent, which
  # the line above just prompted for on a fresh machine. Flag it if still blocked.
  is_dryrun || can_set_appearance || \
    warn "Grant your terminal Automation → System Events so themes can sync macOS Light/Dark (\`omacase doctor\` re-checks)."

  step "8/8  Window manager"
  source "$OMACASE_ROOT/lib/wm.sh"
  omacase_wm

  step "Done"
  success "omacase installed."
  warn "Next: run \`omacase doctor\` and grant Accessibility to OmniWM"
  warn "  (plus Automation → System Events so themes can sync macOS Light/Dark)."
  warn "OmniWM also requires Displays have separate Spaces; a logout applies that setting."
  warn "Don't like the result? \`omacase restore\` rolls back to the pre-install snapshot."
}

# Homebrew requires an explicit trust decision before loading third-party
# packages. Trust only the two exact items in the Brewfile instead of disabling
# enforcement for the entire bundle or every package in their taps.
_brew_trust_declared_third_party() {
  if run brew tap BarutSRB/tap; then
    run brew trust --cask BarutSRB/tap/omniwm || \
      warn "Could not trust the OmniWM cask; Homebrew may skip it."
  else
    warn "Could not add the OmniWM Homebrew tap."
  fi
  if run brew tap finbarr/tap; then
    run brew trust --formula finbarr/tap/yolobox || \
      warn "Could not trust the yolobox formula; Homebrew may skip it."
  else
    warn "Could not add the yolobox Homebrew tap."
  fi
}

# Install the tools declared in ~/.config/mise/config.toml (node + the npm: CLIs
# that ship faster on npm than Homebrew). Idempotent — converges to the config.
# mise is provided by `brew bundle` and activated in dot_zshrc.
_mise_install() {
  have mise || { warn "mise not found (brew bundle should install it) — skipping npm CLIs."; return 0; }
  run mise install -y || warn "mise install had issues — re-run \`mise install\` later."
}

# Grok CLI (xAI) ships as a self-updating native binary that installs into
# ~/.grok rather than Homebrew — the same model as Claude Code, so it lives here
# instead of the Brewfile. Explicit opt-in permits xAI's installer when missing;
# it self-updates thereafter, and the managed dot_zshrc puts ~/.grok/bin on PATH
# and loads its zsh completions.
_grok_install() {
  local installer
  if have grok || [ -x "$HOME/.grok/bin/grok" ]; then
    is_dryrun || success "grok already installed — it self-updates."
    return 0
  fi
  if [ "${OMACASE_INSTALL_GROK:-0}" != 1 ]; then
    info "Skipping Grok CLI's unpinned upstream installer (opt in with OMACASE_INSTALL_GROK=1)."
    return 0
  fi
  have curl || { warn "curl not found — skipping grok CLI install."; return 0; }
  if is_dryrun; then
    log "[dry-run] would download xAI's installer over TLS, then run the complete file"
    return 0
  fi
  installer="$(mktemp)"
  if ! curl --proto '=https' --tlsv1.2 -fsSL \
    https://x.ai/cli/install.sh -o "$installer"; then
    rm -f "$installer"
    warn "grok installer download failed; re-run \`omacase update\` or install from https://x.ai/cli."
    return 0
  fi
  /bin/bash "$installer" || \
    warn "grok install failed; re-run \`omacase update\` or install from https://x.ai/cli."
  rm -f "$installer"
  _grok_strip_zshrc_block
}

# xAI's installer appends its own PATH/compinit block to ~/.zshrc between
# `# >>> grok installer >>>` markers. Our managed dot_zshrc already wires
# ~/.grok (guarded, before the single daily compinit), and ~/.zshrc is a
# symlink into the repo — so the appended block would run compinit twice per
# shell AND dirty the checkout. Strip it, writing through the symlink so the
# link itself survives.
_grok_strip_zshrc_block() {
  local zshrc="$HOME/.zshrc" tmp
  if is_dryrun; then return 0; fi
  [ -f "$zshrc" ] || return 0
  grep -q '^# >>> grok installer >>>' "$zshrc" 2>/dev/null || return 0
  tmp="$(mktemp)"
  sed '/^# >>> grok installer >>>/,/^# <<< grok installer <<</d' "$zshrc" > "$tmp" \
    && cat "$tmp" > "$zshrc"
  rm -f "$tmp"
}

# herdr ships per-agent hooks that report each coding agent's lifecycle state
# (idle/working/blocked/done) back to herdr — that reporting is what drives its
# agent sidebar, notifications, and `herdr agent` commands. Without them a pane
# running an agent is just an anonymous shell to herdr.
#
# Only agents actually on PATH get a hook, so this tracks whatever the Brewfile
# and mise config currently ship (plus opt-in grok). herdr owns the whole
# lifecycle — install is idempotent and versioned, so re-running upgrades a
# stale hook in place; `herdr integration status` reports what is current, and
# `herdr integration uninstall <agent>` removes one.
_herdr_integrations() {
  have herdr || { warn "herdr not found (brew bundle should install it) — skipping agent hooks."; return 0; }
  local agent
  for agent in claude codex opencode pi grok; do
    have "$agent" || continue
    run herdr integration install "$agent" \
      || warn "herdr integration install $agent failed; re-run \`omacase update\`."
  done
}

# Agent harnesses whose config root implies they read a `skills/` directory.
# opencode, pi, and gemini ship no skills directory, so they are skipped rather
# than guessed at — revisit if that changes upstream.
_HERDR_SKILL_HOSTS=(.claude .codex .grok)

# The other half of herdr's agent story: a *skill* describing how to drive herdr
# itself (panes, tabs, workspaces, other agents), which is the opposite
# direction from the state hooks above. `herdr --skill` prints it, so it is
# generated rather than vendored and always matches the installed binary.
#
# ~/.agents/skills is the shared cross-harness store; each harness reads its own
# skills/ directory, which by convention symlinks there. Writing the canonical
# copy once and linking keeps every agent on the same text. Re-running refreshes
# the generated file and picks up harnesses installed since the last run, which
# is what makes this safe for `omacase update` to repeat.
_herdr_skill() {
  have herdr || return 0
  local store="$HOME/.agents/skills/herdr" host dir target
  if is_dryrun; then
    log "[dry-run] would write $store/SKILL.md from \`herdr --skill\`"
  else
    if ! mkdir -p "$store"; then
      warn "Could not create $store — skipping herdr skill."
      return 0
    fi
    if ! herdr --skill > "$store/SKILL.md"; then
      warn "\`herdr --skill\` failed — skipping herdr skill."
      return 0
    fi
  fi

  for host in "${_HERDR_SKILL_HOSTS[@]}"; do
    [ -d "$HOME/$host" ] || continue
    dir="$HOME/$host/skills"
    target="$dir/herdr"
    # Never clobber a skill someone else installed under the same name; an
    # existing link of ours is already correct, so re-running is a no-op.
    if [ -L "$target" ]; then
      if [ "$(readlink "$target")" != "$store" ]; then
        warn "$target points elsewhere — leaving it alone."
      fi
      continue
    fi
    if [ -e "$target" ]; then
      warn "$target exists and is not an Omacase symlink — leaving it alone."
      continue
    fi
    run mkdir -p "$dir"
    run ln -s "$store" "$target"
    is_dryrun || success "herdr skill → $target"
  done
}

# Make `omacase` available on PATH for every shell (zsh/bash/fish) and for GUI
# contexts, by symlinking it into Apple Silicon Homebrew's bin.
# This is what `brew link` does for formulae; exact existing links are a no-op.
_link_command() {
  local bindir; bindir="$(_omacase_bindir)"
  if [ -z "$bindir" ]; then
    warn "No Homebrew bin dir found; \`omacase\` stays available via ~/.zshrc only."
    return 0
  fi
  _link_command_file "$OMACASE_ROOT/bin/omacase" "$bindir/omacase"
  is_dryrun || success "omacase → $bindir/omacase"

  # Tab completion: link _omacase next to Homebrew's other completions.
  # Group-writable dirs anywhere above an fpath entry make compinit prompt
  # "insecure directories?" on every new shell, so strip go-w on the whole
  # chain (Homebrew's documented fix; brew installs can re-add it to share/).
  local zfunc; zfunc="$(_omacase_zfuncdir)"
  local share="${zfunc%/zsh/site-functions}"
  run mkdir -p "$zfunc"
  _link_command_file "$OMACASE_ROOT/completions/_omacase" "$zfunc/_omacase"
  run chmod go-w "$share" "$share/zsh" "$zfunc" "$share/zsh-completions" 2>/dev/null || true
  is_dryrun || success "completion → $zfunc/_omacase"
}

# PATH and completion directories are outside the snapshot boundary. Never
# overwrite an unrelated file there; require the owner to move it explicitly.
_assert_command_link_target() {
  local source="$1" target="$2"
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
      return 0
    fi
    abort "Refusing to overwrite unrelated path: $target"
  fi
}

_preflight_command_links() {
  local bindir zfunc
  bindir="$(_omacase_bindir)"
  [ -n "$bindir" ] || return 0
  zfunc="$(_omacase_zfuncdir)"
  _assert_command_link_target "$OMACASE_ROOT/bin/omacase" "$bindir/omacase"
  _assert_command_link_target "$OMACASE_ROOT/completions/_omacase" "$zfunc/_omacase"
}

_link_command_file() {
  local source="$1" target="$2"
  _assert_command_link_target "$source" "$target"
  if [ -L "$target" ]; then return 0; fi
  run ln -s "$source" "$target"
}

# home/<rel> → its $HOME target, translating chezmoi-style dot_ prefixes
# (dot_zshrc → ~/.zshrc, dot_config/x → ~/.config/x).
_dot_target() {
  printf '%s' "$HOME/$(printf '%s' "$1" | sed -e 's#^dot_#.#' -e 's#/dot_#/.#g')"
}

# Symlink every file under home/ into $HOME, translating chezmoi-style dot_
# prefixes (dot_zshrc → ~/.zshrc, dot_config/x → ~/.config/x). Pre-existing
# real config at a managed target is removed only AFTER _auto_backup saved it.
# Leaf-file granularity lets theme symlinks (e.g. nvim/lua/theme.lua) live
# alongside without polluting the repo.
_link_dotfiles() {
  source "$OMACASE_ROOT/lib/backup.sh"
  # Never write through a top-level config symlink into an external directory.
  # Replace only that symlink; preserve real directories and any unrelated
  # files they contain.
  local t
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    case "$t" in
      "$HOME/.config/"*)
        if [ -L "$t" ] || { [ -e "$t" ] && [ ! -d "$t" ]; }; then
          run rm -rf "$t"
          run mkdir -p "$t"
        fi ;;
    esac
  done < <(_managed_targets)

  # Link each managed leaf. A conflicting leaf was captured by _auto_backup;
  # siblings in the same app directory are deliberately left untouched.
  local src="$OMACASE_ROOT/home" f target
  while IFS= read -r f; do
    target="$(_dot_target "${f#"$src"/}")"
    if [ -e "$target" ] || [ -L "$target" ]; then
      if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
        continue
      fi
      run rm -rf "$target"
    fi
    run mkdir -p "$(dirname "$target")"
    run ln -s "$f" "$target"
  done < <(find "$src" -type f ! -name '.DS_Store' ! -name '*.pyc' ! -path '*/__pycache__/*')
}

omacase_uninstall() {
  source "$OMACASE_ROOT/lib/backup.sh"
  warn "This removes Omacase-managed symlinks & stops its services."
  warn "It does NOT uninstall your Homebrew apps."
  is_dryrun || confirm "Proceed?" || { info "Cancelled."; return; }
  source "$OMACASE_ROOT/lib/wm.sh"; _wm_stop_all || true

  # Extras write root-owned /etc files; never silently sudo during uninstall —
  # point at the explicit revert instead.
  if [ -f /etc/sudoers.d/omacase ]; then
    warn "The sudo-touchid extra is still enabled — revert it with \`omacase extras sudo-touchid off\` before deleting the repo."
  fi

  # Remove only the symlinks Omacase created. (`|| true`: a target that isn't
  # ours must not abort the walk under set -e.)
  local src="$OMACASE_ROOT/home" f target
  while IFS= read -r f; do
    target="$(_dot_target "${f#"$src"/}")"
    { _is_omacase_link "$target" && run rm -f "$target"; } || true
  done < <(find "$src" -type f ! -name '.DS_Store' ! -name '*.pyc' ! -path '*/__pycache__/*')

  # Theme symlinks are created by `omacase theme`, not from home/ — walk the
  # same fragment|target list theme.sh links.
  source "$OMACASE_ROOT/lib/theme.sh"
  local themed
  while IFS='|' read -r _ themed; do
    { _is_omacase_link "$themed" && run rm -f "$themed"; } || true
  done < <(_theme_links)

  # herdr skill links point at ~/.agents, outside the repo, so _is_omacase_link
  # cannot classify them — match the exact target this installer creates. The
  # per-agent state hooks are deliberately left in place: herdr owns their
  # lifecycle and removes them with `herdr integration uninstall <agent>`.
  local skill_store="$HOME/.agents/skills/herdr" host
  for host in "${_HERDR_SKILL_HOSTS[@]}"; do
    target="$HOME/$host/skills/herdr"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$skill_store" ]; then
      run rm -f "$target"
    fi
  done
  { [ -d "$skill_store" ] && run rm -rf "$skill_store"; } || true

  local agent="$HOME/Library/LaunchAgents/org.omacase.omniwm.plist"
  run launchctl bootout "gui/$(id -u)/org.omacase.omniwm" 2>/dev/null || true
  { _is_omacase_link "$agent" && run rm -f "$agent"; } || true

  # Remove the `omacase` command + completion symlinks from Homebrew (only ours).
  local cmd
  for cmd in /opt/homebrew/bin/omacase /opt/homebrew/share/zsh/site-functions/_omacase; do
    { _is_omacase_link "$cmd" && run rm -f "$cmd"; } || true
  done

  success "Omacase symlinks and generated artifacts removed."
  log "To bring back your original config: omacase restore   (see: omacase restore --list)"
}
