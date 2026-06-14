# omacase — ranger colorscheme. Extends ranger's stock Default and recolors the
# file list from the ACTIVE theme. `omacase theme <name>` symlinks the theme's
# fragment (themes/<name>/ranger) to ~/.config/ranger/theme.colors — a tiny
# `key=256-index` table generated from the theme's Ghostty palette (dirs=blue,
# links=cyan, exec=green, …, the same role map as eza). When no table is linked
# (no active theme yet), we fall through to Default untouched.
#
# We use 256-color indices (not ANSI 0-15) so each theme renders in its own hues
# regardless of the terminal's 16-color slots — the previous approach pinned one
# accent (magenta) and bled it into every theme.
#
# ranger picks the class named `Scheme` if present, else the first ColorScheme
# subclass in the module; we name it `Scheme` to stay unambiguous.
from __future__ import absolute_import, division, print_function

import os

import ranger.colorschemes.default as default_scheme

_COLORS = {}
_TABLE = os.path.expanduser("~/.config/ranger/theme.colors")
try:
    with open(_TABLE) as _f:
        for _line in _f:
            _line = _line.strip()
            if not _line or _line.startswith("#") or "=" not in _line:
                continue
            _k, _v = _line.split("=", 1)
            _COLORS[_k.strip()] = int(_v.strip())
except (OSError, ValueError):
    _COLORS = {}


class Scheme(default_scheme.Default):
    def use(self, context):
        fg, bg, attr = default_scheme.Default.use(self, context)
        c = _COLORS
        if not c or not context.in_browser:
            return fg, bg, attr
        # Mirror Default's precedence (later wins), but substitute the theme's
        # 256-color index for fg. Default's bold/bright attrs are preserved.
        if context.media:
            fg = c.get("image", fg) if context.image else c.get("media", fg)
        if context.container:
            fg = c.get("archive", fg)
        if context.directory:
            fg = c.get("directory", fg)
        elif context.executable and not any(
            (context.media, context.container, context.fifo, context.socket)
        ):
            fg = c.get("executable", fg)
        if context.socket:
            fg = c.get("socket", fg)
        if context.fifo or context.device:
            fg = c.get("device", fg)
        if context.link:
            fg = c.get("link", fg) if context.good else c.get("orphan", fg)
        return fg, bg, attr
