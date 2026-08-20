# shellcheck shell=bash
# Terminal font: IoskeleyMono (Iosevka tuned to look like Berkeley Mono), the
# Term + Nerd Font build. Homebrew's cask (font-ioskeley-mono) ships only the
# editor build — no Nerd glyphs and not the strict terminal-grid "Term" metrics —
# so starship/nvim icons would fall back. Upstream recommends exactly this asset
# for Ghostty, so install it from a GitHub release pinned by version AND sha256.
# Fonts are content, not code (see SECURITY.md); they land in a directory we
# own under ~/Library/Fonts, marked so install skips when current and uninstall
# removes only ours. Bump: RELEASING.md → "Font pin".

OMACASE_FONT_VERSION=v2.1.0
OMACASE_FONT_SHA256=2eb905184e40602f6711d84c28448a0056a77de96881bbdee55b9595d40f2265
OMACASE_FONT_URL="https://github.com/ahatem/IoskeleyMono/releases/download/$OMACASE_FONT_VERSION/IoskeleyMono-Term-NerdFont.zip"
OMACASE_FONT_DIR="${OMACASE_FONT_DIR:-$HOME/Library/Fonts/IoskeleyMono-Term-NerdFont}"
OMACASE_FONT_FAMILY="IoskeleyMonoTerm Nerd Font Mono"   # what Ghostty's font-family names
_FONT_MARKER=".omacase-version"

_font_installed_version() { cat "$OMACASE_FONT_DIR/$_FONT_MARKER" 2>/dev/null || true; }

# Idempotent: skip when the marker matches the pin; otherwise fetch, verify the
# checksum, and (re)place the Normal-width TTFs. Nonzero on any failure so
# `require` ledgers it — Ghostty falls back to JetBrains Mono meanwhile.
_font_install() {
  if [ "$(_font_installed_version)" = "$OMACASE_FONT_VERSION" ]; then
    is_dryrun || success "IoskeleyMono $OMACASE_FONT_VERSION already installed."
    return 0
  fi
  if is_dryrun; then
    log "[dry-run] would install IoskeleyMono $OMACASE_FONT_VERSION (Term NerdFont) → $OMACASE_FONT_DIR"
    return 0
  fi
  have curl || { error "curl not found — cannot fetch IoskeleyMono."; return 1; }
  local tmp zip src
  tmp="$(mktemp -d)"; zip="$tmp/font.zip"
  if ! curl --proto '=https' --tlsv1.2 -fsSL "$OMACASE_FONT_URL" -o "$zip"; then
    rm -rf "$tmp"; error "IoskeleyMono download failed ($OMACASE_FONT_URL)."; return 1
  fi
  if ! printf '%s  %s\n' "$OMACASE_FONT_SHA256" "$zip" | shasum -a 256 -c -- >/dev/null 2>&1; then
    rm -rf "$tmp"
    error "IoskeleyMono checksum mismatch — refusing to install it. (Upstream may have re-cut $OMACASE_FONT_VERSION; update omacase.)"
    return 1
  fi
  if ! unzip -oq "$zip" -d "$tmp/x"; then
    rm -rf "$tmp"; error "IoskeleyMono archive could not be extracted."; return 1
  fi
  # Normal width only; SemiCondensed ships in the same zip but would double the
  # installed family set for no terminal benefit.
  src="$(find "$tmp/x" -type d -name Normal | head -1)"
  if [ -z "$src" ] || ! ls "$src"/*.ttf >/dev/null 2>&1; then
    rm -rf "$tmp"; error "IoskeleyMono archive layout changed (no Normal/*.ttf) — update omacase."; return 1
  fi
  # Replace wholesale only when the directory is provably ours (marker present);
  # an unmarked directory at the same path is someone else's — merge into it.
  if [ -f "$OMACASE_FONT_DIR/$_FONT_MARKER" ]; then rm -rf "$OMACASE_FONT_DIR"; fi
  mkdir -p "$OMACASE_FONT_DIR"
  cp -f "$src"/*.ttf "$OMACASE_FONT_DIR"/
  printf '%s\n' "$OMACASE_FONT_VERSION" > "$OMACASE_FONT_DIR/$_FONT_MARKER"
  rm -rf "$tmp"
  success "IoskeleyMono $OMACASE_FONT_VERSION installed → $OMACASE_FONT_DIR (\"$OMACASE_FONT_FAMILY\")"
}

# Remove the font only when the marker proves Omacase put it there.
_font_uninstall() {
  [ -f "$OMACASE_FONT_DIR/$_FONT_MARKER" ] || return 0
  run rm -rf "$OMACASE_FONT_DIR"
  is_dryrun || success "Removed IoskeleyMono (Omacase-installed font)."
}
