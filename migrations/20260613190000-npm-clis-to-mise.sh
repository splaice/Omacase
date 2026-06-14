# shellcheck shell=bash
# gemini-cli and mermaid-cli now come from mise's npm: backend (declared in
# ~/.config/mise/config.toml) so they track npm releases instead of waiting on a
# Homebrew bump. Remove the Homebrew copies once mise is providing the
# replacement.
#
# These were `brew install`ed by hand; omacase now manages them via mise, so the
# brew duplicates should go. Guarded: only uninstall the brew copy when the mise
# tool is actually installed, so we never strand the tool.
#
# NOTE: we deliberately do NOT uninstall brew's `node` here. It may be an orphan
# now, but removing it can cascade-remove shared deps that brew CASKS quietly
# depend on (e.g. gcloud-cli → python@3.13 — brew's formula cleanup doesn't see
# cask deps). mise's node wins on PATH anyway, so a stray brew node is harmless.
#
# (Filename uses a YYYYMMDDHHMMSS id so it sorts AFTER the date-only
# 20260613-remove-dropped-apps migration under the runner's C-collation order.)
migrate() {
  _mise_has() { mise ls --installed 2>/dev/null | grep -q "npm:$1"; }

  if _mise_has "@google/gemini-cli" && brew list gemini-cli >/dev/null 2>&1; then
    run brew uninstall gemini-cli || warn "migrate: couldn't uninstall gemini-cli (skipped)."
  fi
  if _mise_has "@mermaid-js/mermaid-cli" && brew list mermaid-cli >/dev/null 2>&1; then
    run brew uninstall mermaid-cli || warn "migrate: couldn't uninstall mermaid-cli (skipped)."
  fi
}
