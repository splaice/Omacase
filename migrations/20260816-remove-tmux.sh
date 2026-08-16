# shellcheck shell=bash
# Omacase no longer ships tmux: herdr is the multiplexer (agent-aware, sessions
# survive disconnect) and Ghostty covers splits/tabs natively, so tmux was the
# odd one out. Remove the Omacase-managed copy and config.
#
# SCOPE: only the exact things Omacase shipped — the `tmux` formula (guarded by
# "is it installed") and the managed ~/.config/tmux/tmux.conf symlink (only if
# it still points into this repo). A user's own tmux setup is untouched.
migrate() {
  if brew list --formula tmux >/dev/null 2>&1; then
    run brew uninstall tmux || warn "migrate: couldn't uninstall 'tmux' (skipped)."
  fi

  local link="$HOME/.config/tmux/tmux.conf"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$OMACASE_ROOT/home/dot_config/tmux/tmux.conf" ]; then
    run rm -f "$link"
    run rmdir "$HOME/.config/tmux" 2>/dev/null || true
  fi
}
