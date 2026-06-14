#!/usr/bin/env python3
"""Generate per-theme CLI color fragments (eza / ranger / glow) for every theme.

Each theme's canonical colors are its Ghostty ANSI palette (themes/<n>/ghostty,
or — when that just selects a Ghostty built-in like "Catppuccin Mocha" — the
palette Ghostty itself ships). We map the standard dircolors/Glamour *roles*
(directories=blue, links=cyan, executables=green, archives=red, media=magenta,
docs/devices=yellow, metadata=grey) onto each palette, so every theme is colored
the SAME way, just in its own hues. No theme is special-cased.

  themes/<n>/eza     truecolor LS_COLORS/EZA_COLORS  -> ~/.config/eza/theme.sh
  themes/<n>/ranger  key=256-index pairs             -> ~/.config/ranger/theme.colors
  themes/<n>/glow    Glamour StyleConfig (hex)        -> ~/.config/glow/theme.json

Run from anywhere: `python3 scripts/gen-cli-theme-colors.py`. Idempotent.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEMES = os.path.join(ROOT, "themes")
GHOSTTY_THEMES = "/Applications/Ghostty.app/Contents/Resources/ghostty/themes"


def _hex(s):
    s = s.strip().lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def _hexstr(rgb):
    return "#%02X%02X%02X" % rgb


def _rgb_seq(rgb):
    return "38;2;%d;%d;%d" % rgb


def parse_palette(text):
    """Return (background, foreground, [p0..p15]) as #rrggbb, or None if absent."""
    pal = {}
    bg = fg = None
    for line in text.splitlines():
        m = re.match(r"\s*palette\s*=\s*(\d+)\s*=\s*#?([0-9A-Fa-f]{6})", line)
        if m:
            pal[int(m.group(1))] = "#" + m.group(2)
            continue
        m = re.match(r"\s*background\s*=\s*#?([0-9A-Fa-f]{6})", line)
        if m:
            bg = "#" + m.group(1)
            continue
        m = re.match(r"\s*foreground\s*=\s*#?([0-9A-Fa-f]{6})", line)
        if m:
            fg = "#" + m.group(1)
    if len(pal) < 16:
        return None
    return bg, fg, [pal[i] for i in range(16)]


def builtin_palette(name):
    """Resolve a Ghostty built-in theme name to its palette file (case-insensitive)."""
    if not os.path.isdir(GHOSTTY_THEMES):
        return None
    want = name.strip().lower()
    for fn in os.listdir(GHOSTTY_THEMES):
        if fn.lower() == want:
            with open(os.path.join(GHOSTTY_THEMES, fn)) as f:
                return parse_palette(f.read())
    return None


def resolve(theme_dir):
    g = os.path.join(theme_dir, "ghostty")
    if not os.path.exists(g):
        return None
    text = open(g).read()
    pal = parse_palette(text)
    if pal:
        return pal
    m = re.search(r"^\s*theme\s*=\s*(.+?)\s*$", text, re.M)
    if m:
        return builtin_palette(m.group(1))
    return None


# ---- xterm-256 nearest (for ranger, which is 256-color not truecolor) --------
def _cube(v):
    # xterm 6x6x6 cube levels
    levels = [0, 95, 135, 175, 215, 255]
    best, bi = 1 << 30, 0
    for i, lv in enumerate(levels):
        d = abs(lv - v)
        if d < best:
            best, bi = d, i
    return bi, levels[bi]


def nearest256(hexstr):
    r, g, b = _hex(hexstr)
    # candidate from the color cube
    ri, rv = _cube(r)
    gi, gv = _cube(g)
    bi, bv = _cube(b)
    cube_idx = 16 + 36 * ri + 6 * gi + bi
    cube_err = (rv - r) ** 2 + (gv - g) ** 2 + (bv - b) ** 2
    # candidate from the grayscale ramp (232..255)
    gray = round((r + g + b) / 3)
    gi2 = min(23, max(0, round((gray - 8) / 10)))
    gv2 = 8 + 10 * gi2
    gray_idx = 232 + gi2
    gray_err = sum((gv2 - c) ** 2 for c in (r, g, b))
    return gray_idx if gray_err < cube_err else cube_idx


def roles(pal):
    bg, fg, p = pal
    return {
        "accent": p[4],   # blue    -> directories, headings
        "link": p[6],     # cyan    -> symlinks, h2/h4
        "exec": p[2],     # green   -> executables, strings
        "archive": p[1],  # red     -> archives, errors
        "special": p[3],  # yellow  -> pipes/devices, docs, numbers
        "media": p[5],    # magenta -> media files, sockets
        "danger": p[9],   # br red  -> orphans / missing
        "accent_hi": p[12],  # br blue -> emphasis (owner = you)
        "muted": p[8],    # br black-> metadata / dim
        "text": fg or p[7],
        "bg": bg or p[0],
    }


# ---- eza / LS_COLORS ---------------------------------------------------------
def gen_eza(name, r):
    c = {k: _rgb_seq(_hex(v)) for k, v in r.items()}
    ls = {
        "di": c["accent"], "ln": c["link"], "ex": c["exec"], "so": c["media"],
        "pi": c["special"], "bd": c["special"], "cd": c["special"],
        "or": c["danger"], "mi": c["danger"], "su": c["danger"],
        "sg": c["special"], "tw": c["special"], "ow": c["link"], "st": c["link"],
    }
    arc = c["archive"]
    for e in ("tar", "tgz", "zip", "gz", "bz2", "xz", "7z", "rar"):
        ls["*." + e] = arc
    doc = c["special"]
    for e in ("md", "json", "toml", "yaml", "yml"):
        ls["*." + e] = doc
    ls["*.lock"] = c["muted"]
    ez = {
        "da": c["muted"], "sn": c["exec"], "sb": c["muted"],
        "ur": c["text"], "uw": c["danger"], "ux": c["exec"],
        "gr": c["muted"], "gw": c["muted"], "gx": c["muted"],
        "tr": c["muted"], "tw": c["muted"], "tx": c["muted"],
        "uu": c["accent_hi"], "un": c["muted"], "xx": c["muted"],
        "ga": c["exec"], "gm": c["special"], "gd": c["danger"],
        "gv": c["accent"], "gt": c["link"],
    }
    ls_s = ":".join("%s=%s" % kv for kv in ls.items())
    ez_s = ":".join("%s=%s" % kv for kv in ez.items())
    return (
        "# %s — eza / ls colors (sourced as ~/.config/eza/theme.sh by zsh).\n"
        "# Generated by scripts/gen-cli-theme-colors.py from the theme's Ghostty\n"
        "# palette: directories=blue, links=cyan, exec=green, archives=red,\n"
        "# media=magenta, docs/devices=yellow, metadata=grey.\n"
        "export LS_COLORS=\"%s\"\n\n"
        "export EZA_COLORS=\"%s\"\n" % (name, ls_s, ez_s)
    )


# ---- ranger (256-color index data, read by colorschemes/omacase.py) ----------
def gen_ranger(name, r):
    idx = {
        "directory": r["accent"], "link": r["link"], "executable": r["exec"],
        "socket": r["media"], "device": r["special"], "image": r["special"],
        "media": r["media"], "archive": r["archive"], "orphan": r["danger"],
    }
    lines = [
        "# %s — ranger file colors (256-color indices)." % name,
        "# Generated by scripts/gen-cli-theme-colors.py; nearest xterm-256 of the",
        "# theme's Ghostty palette. Linked to ~/.config/ranger/theme.colors and read",
        "# by colorschemes/omacase.py. Same role map as eza (dirs=blue, …).",
    ]
    for k in ("directory", "link", "executable", "socket", "device",
              "image", "media", "archive", "orphan"):
        lines.append("%s=%d" % (k, nearest256(idx[k])))
    return "\n".join(lines) + "\n"


# ---- glow (Glamour StyleConfig; hex colors) ----------------------------------
def gen_glow(name, r):
    A, L, E = r["accent"], r["link"], r["exec"]
    RD, SP, MU = r["archive"], r["special"], r["muted"]
    BG, TXT = r["bg"], r["text"]
    style = {
        "document": {"block_prefix": "\n", "block_suffix": "\n", "margin": 2},
        "block_quote": {"indent": 1, "indent_token": "│ ", "color": MU},
        "paragraph": {},
        "list": {"level_indent": 2},
        "heading": {"block_suffix": "\n", "color": A, "bold": True},
        "h1": {"prefix": " ", "suffix": " ", "color": BG,
               "background_color": A, "bold": True},
        "h2": {"prefix": "## ", "color": L},
        "h3": {"prefix": "### ", "color": A},
        "h4": {"prefix": "#### ", "color": L},
        "h5": {"prefix": "##### ", "color": A},
        "h6": {"prefix": "###### ", "color": MU, "bold": False},
        "text": {},
        "strikethrough": {"crossed_out": True},
        "emph": {"italic": True},
        "strong": {"bold": True},
        "hr": {"color": MU, "format": "\n--------\n"},
        "item": {"block_prefix": "• "},
        "enumeration": {"block_prefix": ". "},
        "task": {"ticked": "[✓] ", "unticked": "[ ] "},
        "link": {"color": L, "underline": True},
        "link_text": {"color": A, "bold": True},
        "image": {"color": A, "underline": True},
        "image_text": {"color": MU, "format": "Image: {{.text}} →"},
        "code": {"prefix": " ", "suffix": " ", "color": E,
                 "background_color": MU},
        "code_block": {
            "margin": 2,
            "chroma": {
                "text": {},
                "error": {"color": RD},
                "comment": {"color": MU, "italic": True},
                "comment_preproc": {"color": SP},
                "keyword": {"color": L},
                "keyword_reserved": {"color": L},
                "keyword_namespace": {"color": L},
                "keyword_type": {"color": A},
                "operator": {"color": TXT},
                "punctuation": {"color": TXT},
                "name": {},
                "name_builtin": {"color": L},
                "name_tag": {"color": A},
                "name_attribute": {"color": SP},
                "name_class": {"color": A, "bold": True},
                "name_constant": {"color": SP},
                "name_decorator": {"color": SP},
                "name_function": {"color": A, "bold": True},
                "literal": {},
                "literal_number": {"color": SP},
                "literal_string": {"color": E},
                "literal_string_escape": {"color": L},
                "generic_deleted": {"color": RD},
                "generic_emph": {"italic": True},
                "generic_inserted": {"color": E},
                "generic_strong": {"bold": True},
                "generic_subheading": {"color": MU},
            },
        },
        "table": {},
        "definition_list": {},
        "definition_term": {},
        "definition_description": {"block_prefix": "\n\U0001f836 "},
        "html_block": {},
        "html_span": {},
    }
    return json.dumps(style, indent=2, ensure_ascii=False) + "\n"


def main():
    names = sorted(d for d in os.listdir(THEMES)
                   if os.path.isdir(os.path.join(THEMES, d)))
    failed = []
    for name in names:
        tdir = os.path.join(THEMES, name)
        pal = resolve(tdir)
        if not pal:
            failed.append(name)
            print("  !! %-20s could not resolve palette" % name)
            continue
        r = roles(pal)
        open(os.path.join(tdir, "eza"), "w").write(gen_eza(name, r))
        open(os.path.join(tdir, "ranger"), "w").write(gen_ranger(name, r))
        open(os.path.join(tdir, "glow"), "w").write(gen_glow(name, r))
        print("  ok %-20s di=%s ln=%s ex=%s" %
              (name, r["accent"], r["link"], r["exec"]))
    print("\n%d themes written, %d failed" % (len(names) - len(failed), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
