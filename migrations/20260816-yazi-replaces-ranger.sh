# shellcheck shell=bash
# yazi replaces ranger as the `omacase files` file manager (async, image
# previews that work in Ghostty). `omacase update` runs `brew bundle` before
# migrations, so yazi is already installed when this runs; here we remove the
# ranger Omacase used to ship and its managed config.
#
# SCOPE: only the exact things Omacase shipped — the `ranger` formula (guarded
# by "is it installed") and the managed ~/.config/ranger symlinks (only ones
# pointing into this repo, plus the __pycache__ their colorscheme compiled to).
# A user's own ranger setup is untouched.
migrate() {
  if brew list --formula ranger >/dev/null 2>&1; then
    run brew uninstall ranger || warn "migrate: couldn't uninstall 'ranger' (skipped)."
  fi

  local dir="$HOME/.config/ranger" link
  for link in "$dir/rc.conf" "$dir/colorschemes/omacase.py"; do
    if [ -L "$link" ]; then
      case "$(readlink "$link")" in
        "$OMACASE_ROOT"/home/dot_config/ranger/*) run rm -f "$link" ;;
      esac
    fi
  done
  run rm -rf "$dir/colorschemes/__pycache__"
  run rmdir "$dir/colorschemes" "$dir" 2>/dev/null || true
}
