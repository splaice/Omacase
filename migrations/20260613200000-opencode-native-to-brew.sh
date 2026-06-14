# shellcheck shell=bash
# opencode now comes from Homebrew (brew "opencode") instead of the opencode.ai
# native installer at ~/.opencode. Remove the stale native install once brew is
# providing opencode — its config/auth (~/.config/opencode, ~/.local/share/opencode)
# lives elsewhere and is untouched. The native ~/.opencode/bin PATH line was also
# dropped from dot_zshrc, so brew's opencode wins on PATH.
migrate() {
  if brew list opencode >/dev/null 2>&1 && [ -e "$HOME/.opencode/bin/opencode" ]; then
    run rm -rf "$HOME/.opencode" || warn "migrate: couldn't remove ~/.opencode (skipped)."
  fi
}
