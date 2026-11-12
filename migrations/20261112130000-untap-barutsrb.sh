# shellcheck shell=bash
# OmniWM moved to Homebrew's official cask and BarutSRB/tap was retired (it now
# only redirects). Omacase added that tap, so remove it. `brew untap` refuses
# while any installed package still comes from the tap, so this never removes
# OmniWM — best-effort by design.
migrate() {
  if brew tap 2>/dev/null | grep -qx 'barutsrb/tap'; then
    brew untap barutsrb/tap >/dev/null 2>&1 ||
      warn "Could not untap barutsrb/tap (an install still references it); safe to leave."
  fi
  return 0
}
