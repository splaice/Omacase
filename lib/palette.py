#!/usr/bin/env python3
"""omacase palette — live editor for a theme's Ghostty ANSI palette.

Edit the 16 ANSI slots (+ background / foreground / cursor / selection) and see,
in TRUECOLOR, exactly how an `ls`/eza listing would look after the change —
without reloading Ghostty over and over. The preview renders each entry in the
RGB of the slot it maps to (via $LS_COLORS roles: directories=blue/4,
links=cyan/6, exec=green/2, archives=red/1, media=magenta/5, docs=yellow/3, …),
so tweaking slot 4 recolors directories instantly.

Usage: omacase palette [theme]   (lib/palette.sh resolves the ghostty file)
Keys are shown in the footer. Saving writes the hex values back in place,
preserving comments and layout.
"""
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import termios
import tty

# ---- ANSI slot metadata ------------------------------------------------------
ANSI_NAMES = [
    "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
    "br black", "br red", "br green", "br yellow", "br blue", "br magenta",
    "br cyan", "br white",
]
NAMED_KEYS = [  # editable non-palette colors, in display order
    ("background", "background"),
    ("foreground", "foreground"),
    ("cursor-color", "cursor"),
    ("selection-background", "selection bg"),
    ("selection-foreground", "selection fg"),
]

ESC = "\x1b"
CSI = ESC + "["


def hexrgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def fg(rgb):
    return "%s38;2;%d;%d;%dm" % (CSI, *rgb)


def bg(rgb):
    return "%s48;2;%d;%d;%dm" % (CSI, *rgb)


RESET = CSI + "0m"
BOLD = CSI + "1m"
REVERSE = CSI + "7m"

_ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


def vlen(s):
    """Visible width: characters that actually take a cell (escapes stripped)."""
    return len(_ANSI_RE.sub("", s))


def vtrunc(s, width):
    """Truncate to `width` visible cells, preserving escape sequences."""
    out, w, i = [], 0, 0
    while i < len(s) and w < width:
        m = _ANSI_RE.match(s, i)
        if m:
            out.append(m.group(0))
            i = m.end()
            continue
        out.append(s[i])
        w += 1
        i += 1
    out.append(RESET)
    return "".join(out)


# ---- file model: parse, keep editable colors, rewrite in place ---------------
class Color:
    def __init__(self, cid, label, rgb, line_idx, prefix, suffix, upper, hashed):
        self.id = cid          # 'palette4' / 'background'
        self.label = label     # 'blue' / 'background'
        self.rgb = rgb
        self.line_idx = line_idx
        self.prefix = prefix   # text before the hex on its line
        self.suffix = suffix   # text after
        self.upper = upper     # original hex case
        self.hashed = hashed   # original had a leading '#'

    def hexstr(self):
        s = "%02x%02x%02x" % self.rgb
        if self.upper:
            s = s.upper()
        return ("#" if self.hashed else "") + s

    def render_line(self):
        return self.prefix + self.hexstr() + self.suffix


PAL_RE = re.compile(r"^(\s*palette\s*=\s*(\d+)\s*=\s*)(#?)([0-9A-Fa-f]{6})(.*)$")
KEY_RE = re.compile(
    r"^(\s*(background|foreground|cursor-color|cursor-text|"
    r"selection-background|selection-foreground)\s*=\s*)(#?)([0-9A-Fa-f]{6})(.*)$"
)


def parse(path):
    with open(path) as f:
        lines = f.read().split("\n")
    pal = {}      # n -> Color
    named = {}    # key -> Color
    for i, line in enumerate(lines):
        m = PAL_RE.match(line)
        if m:
            n = int(m.group(2))
            pal[n] = Color("palette%d" % n, ANSI_NAMES[n] if n < 16 else str(n),
                           hexrgb(m.group(4)), i, m.group(1),
                           m.group(5), m.group(4).isupper(), bool(m.group(3)))
            continue
        m = KEY_RE.match(line)
        if m:
            key = m.group(2)
            label = dict(NAMED_KEYS).get(key, key)
            named[key] = Color(key, label, hexrgb(m.group(4)), i,
                               m.group(1), m.group(5),
                               m.group(4).isupper(), bool(m.group(3)))
    # Ordered editable list: palette 0..15, then the named keys present.
    order = [pal[n] for n in range(16) if n in pal]
    for key, _label in NAMED_KEYS:
        if key in named:
            order.append(named[key])
    return lines, order, pal, named


def save(path, lines, colors):
    out = list(lines)
    for c in colors:
        out[c.line_idx] = c.render_line()
    with open(path, "w") as f:
        f.write("\n".join(out))


# ---- $LS_COLORS -> role map (which slot a file type uses) --------------------
DEFAULT_LS = (
    "di=1;34:ln=1;36:ex=1;32:so=1;35:pi=33:bd=1;33:cd=1;33:or=1;31:mi=1;31:"
    "*.tar=31:*.zip=31:*.gz=31:*.7z=31:*.png=35:*.jpg=35:*.svg=35:*.mp4=35:"
    "*.md=33:*.json=33:*.yaml=33:*.yml=33:*.toml=33:*.lock=90"
)
# xterm 6x6x6 cube + grayscale, for any 38;5;N with N>=16 in LS_COLORS.
_CUBE = [0, 95, 135, 175, 215, 255]


def xterm256(n):
    if n < 16:
        return None  # a palette slot, resolve live
    if n >= 232:
        v = 8 + (n - 232) * 10
        return (v, v, v)
    n -= 16
    return (_CUBE[n // 36], _CUBE[(n // 6) % 6], _CUBE[n % 6])


def parse_ls_colors(s):
    rules = {}
    for part in s.split(":"):
        if "=" in part:
            k, v = part.split("=", 1)
            rules[k] = v
    return rules


def sgr_slot(sgr):
    """Return (slot_or_None, literal_rgb_or_None, bold) for an LS_COLORS value."""
    toks = sgr.split(";")
    bold = "1" in toks
    i = 0
    while i < len(toks):
        t = toks[i]
        if t in ("38", "48") and i + 1 < len(toks):
            if toks[i + 1] == "5" and i + 2 < len(toks):
                n = int(toks[i + 2])
                return (n if n < 16 else None, xterm256(n), bold)
            if toks[i + 1] == "2" and i + 4 < len(toks):
                return (None, (int(toks[i + 2]), int(toks[i + 3]),
                               int(toks[i + 4])), bold)
            i += 3
            continue
        if t.isdigit():
            n = int(t)
            if 30 <= n <= 37:
                return (n - 30, None, bold)
            if 90 <= n <= 97:
                return (n - 90 + 8, None, bold)
        i += 1
    return (None, None, bold)  # no color -> foreground


# Example listing: (perms, name, suffix, LS_COLORS key, symlink target)
SAMPLE = [
    ("drwxr-xr-x", "src", "/", "di", None),
    ("drwxr-xr-x", "assets", "/", "di", None),
    ("lrwxr-xr-x", "current", "", "ln", "releases/v2"),
    ("-rwxr-xr-x", "build.sh", "*", "ex", None),
    ("-rw-r--r--", "backup.zip", "", "*.zip", None),
    ("-rw-r--r--", "logo.png", "", "*.png", None),
    ("-rw-r--r--", "README.md", "", "*.md", None),
    ("-rw-r--r--", "package.json", "", "*.json", None),
    ("-rw-r--r--", "Cargo.lock", "", "*.lock", None),
    ("-rw-r--r--", "notes.txt", "", None, None),
    ("-rw-r--r--", "LICENSE", "", None, None),
]


# ---- raw terminal I/O --------------------------------------------------------
def read_key(timeout=None):
    if timeout is not None:
        r, _, _ = select.select([sys.stdin], [], [], timeout)
        if not r:
            return None
    ch = sys.stdin.read(1)
    if ch != ESC:
        return ch
    # possible escape sequence (arrows): peek for more bytes briefly
    r, _, _ = select.select([sys.stdin], [], [], 0.03)
    if not r:
        return "ESC"
    seq = sys.stdin.read(1)
    if seq == "[":
        code = sys.stdin.read(1)
        return {"A": "UP", "B": "DOWN", "C": "RIGHT", "D": "LEFT"}.get(code, None)
    return None


def write(s):
    sys.stdout.write(s)


# ---- the editor --------------------------------------------------------------
class Editor:
    def __init__(self, path, theme, active_theme):
        self.path = path
        self.theme = theme
        self.active = (theme == active_theme)
        self.lines, self.colors, self.pal, self.named = parse(path)
        self.sel = 0          # index into self.colors
        self.chan = 0         # 0/1/2 = R/G/B
        self.dirty = False
        self.msg = ""
        ls = os.environ.get("LS_COLORS") or DEFAULT_LS
        self.rules = parse_ls_colors(ls)
        # reverse map: slot -> [roles] for the left-panel hints
        self.slot_roles = {}
        role_label = {"di": "directories", "ln": "symlinks", "ex": "executables",
                      "*.zip": "archives", "*.png": "media", "*.md": "docs",
                      "*.lock": "lock files"}
        for key, label in role_label.items():
            if key in self.rules:
                slot, _, _ = sgr_slot(self.rules[key])
                if slot is not None:
                    self.slot_roles.setdefault(slot, []).append(label)

    # --- color lookups for the preview ---
    def slot_rgb(self, n):
        c = self.pal.get(n)
        return c.rgb if c else (128, 128, 128)

    def file_style(self, key):
        """(rgb, bold) for a sample file given its LS_COLORS key."""
        if key is None or key not in self.rules:
            fgc = self.named.get("foreground")
            return (fgc.rgb if fgc else (200, 200, 200)), False
        slot, lit, bold = sgr_slot(self.rules[key])
        if slot is not None:
            return self.slot_rgb(slot), bold
        if lit is not None:
            return lit, bold
        fgc = self.named.get("foreground")
        return (fgc.rgb if fgc else (200, 200, 200)), bold

    # --- rendering ---
    # Every line is positioned absolutely with CSI<row>;<col>H. In raw mode a
    # bare "\n" is a line feed WITHOUT a carriage return, so relative newlines
    # stair-step; absolute moves sidestep that entirely. Visible widths are
    # measured with vlen() (escapes stripped) so padding never overflows/wraps.
    RIGHT = 48  # visible column where the preview panel starts

    def render(self):
        cols, _ = shutil.get_terminal_size((96, 30))
        mutec = self.slot_rgb(8)
        bgc = self.named["background"].rgb if "background" in self.named else (0, 0, 0)
        left = self.left_rows()
        right = self.right_rows(bgc)
        # Wrap the frame in synchronized-update markers (mode 2026, which Ghostty
        # supports) so the whole redraw lands atomically — no flicker.
        buf = [CSI + "?2026h" + CSI + "2J"]

        def put(row, s):
            buf.append("%s%d;1H%s%sK" % (CSI, row, vtrunc(s, cols - 1), CSI))

        star = (fg(self.slot_rgb(2)) + " ●" + RESET) if self.dirty else ""
        na = "" if self.active else fg(mutec) + "   (not the active theme)" + RESET
        put(1, "  " + BOLD + "omacase palette " + RESET
            + fg(self.slot_rgb(5)) + "· " + self.theme + RESET + star + na)

        n = max(len(left), len(right))
        for i in range(n):
            lcell = left[i] if i < len(left) else ""
            rcell = right[i] if i < len(right) else ""
            pad = " " * max(2, self.RIGHT - vlen(lcell))
            put(3 + i, "  " + lcell + pad + rcell)

        frow = 4 + n
        put(frow, "  " + fg(mutec) + "↑/↓ slot · ←/→ ±1 · [ / ] ±16 · "
            "Tab channel · e hex · s save · a apply · u revert · q quit" + RESET)
        put(frow + 1, "  " + (fg(self.slot_rgb(2)) + self.msg + RESET if self.msg else ""))
        buf.append("%s%d;1H" % (CSI, frow + 3))  # park cursor below
        buf.append(CSI + "?2026l")               # end synchronized update
        write("".join(buf))
        sys.stdout.flush()

    def left_rows(self):
        rows = []
        for idx, c in enumerate(self.colors):
            selected = idx == self.sel
            swatch = bg(c.rgb) + "   " + RESET
            marker = (fg(self.slot_rgb(5)) + "▸" + RESET) if selected else " "
            base = "%s %s %s %s" % (marker, swatch, c.label.ljust(12),
                                    c.hexstr().lower().ljust(7))
            if selected:
                chans = []
                for ci, (cn, cv) in enumerate(zip("rgb", c.rgb)):
                    tok = "%s%d" % (cn, cv)
                    if ci == self.chan:
                        tok = REVERSE + tok + RESET  # active channel
                    chans.append(tok)
                base += "  " + " ".join(chans)
            elif c.id.startswith("palette"):
                roles = self.slot_roles.get(int(c.id[7:]))
                if roles:
                    base += fg(self.slot_rgb(8)) + " · " + ", ".join(roles) + RESET
            rows.append(base)
        return rows

    def right_rows(self, bgc):
        mutec = self.slot_rgb(8)
        rows = [fg(mutec) + "example listing — eza" + RESET]
        for perms, name, suffix, key, target in SAMPLE:
            rgb, bold = self.file_style(key)
            body = (fg(mutec) + perms + RESET + bg(bgc) + "  "
                    + (BOLD if bold else "") + fg(rgb) + name + suffix + RESET)
            if target:
                body += (bg(bgc) + fg(mutec) + " → " + RESET
                         + bg(bgc) + fg(mutec) + target + RESET)
            # one continuous theme-background panel, padded to a fixed width
            visible = vlen(body)
            row = bg(bgc) + " " + body + bg(bgc) + " " * max(1, 30 - visible) + RESET
            rows.append(row)
        rows.append("")
        strip = "".join(bg(self.slot_rgb(n)) + "  " + RESET for n in range(16))
        rows.append(strip + fg(mutec) + "  slots 0–15" + RESET)
        return rows

    # --- editing ---
    def cur(self):
        return self.colors[self.sel]

    def adjust(self, delta):
        c = self.cur()
        rgb = list(c.rgb)
        rgb[self.chan] = max(0, min(255, rgb[self.chan] + delta))
        c.rgb = tuple(rgb)
        self.dirty = True

    def enter_hex(self):
        c = self.cur()
        buf = ""
        while True:
            self.msg = "hex: #%s_   (6 digits, Enter to apply, Esc to cancel)" % buf
            self.render()
            k = read_key()
            if k in ("\r", "\n"):
                if len(buf) == 6:
                    c.rgb = hexrgb(buf)
                    c.upper = buf.isupper() or c.upper
                    self.dirty = True
                    self.msg = ""
                else:
                    self.msg = "need 6 hex digits"
                return
            if k == "ESC":
                self.msg = ""
                return
            if k in ("\x7f", "\b"):
                buf = buf[:-1]
            elif k and len(k) == 1 and k in "0123456789abcdefABCDEF" and len(buf) < 6:
                buf += k

    def apply_live(self):
        save(self.path, self.lines, self.colors)
        self.dirty = False
        if not self.active:
            self.msg = "saved — run `omacase theme %s` to see it live" % self.theme
            return
        try:
            out = subprocess.run(["ps", "-Axo", "pid=,args="],
                                 capture_output=True, text=True).stdout
            sent = 0
            for ln in out.splitlines():
                parts = ln.split()
                if len(parts) == 2 and parts[1] == \
                        "/Applications/Ghostty.app/Contents/MacOS/ghostty":
                    os.kill(int(parts[0]), signal.SIGUSR2)
                    sent += 1
            self.msg = "saved + reloaded Ghostty" if sent else "saved (Ghostty not running)"
        except Exception as e:  # noqa: BLE001
            self.msg = "saved (reload failed: %s)" % e

    def run(self):
        while True:
            self.render()
            k = read_key()
            if k is None:
                continue
            if k in ("q", "Q", "ESC"):
                if self.dirty:
                    self.msg = "unsaved changes — press q again to discard, s to save"
                    self.render()
                    k2 = read_key()
                    if k2 in ("q", "Q", "ESC"):
                        return
                    if k2 in ("s", "S"):
                        save(self.path, self.lines, self.colors)
                        return
                    self.msg = ""
                    continue
                return
            elif k in ("UP", "k"):
                self.sel = (self.sel - 1) % len(self.colors)
                self.msg = ""
            elif k in ("DOWN", "j"):
                self.sel = (self.sel + 1) % len(self.colors)
                self.msg = ""
            elif k in ("LEFT", "h"):
                self.adjust(-1)
            elif k in ("RIGHT", "l"):
                self.adjust(+1)
            elif k == "[":
                self.adjust(-16)
            elif k == "]":
                self.adjust(+16)
            elif k in ("\t", "c"):
                self.chan = (self.chan + 1) % 3
            elif k in ("e", "E"):
                self.enter_hex()
            elif k in ("s", "S"):
                save(self.path, self.lines, self.colors)
                self.dirty = False
                self.msg = "saved to themes/%s/ghostty" % self.theme
            elif k in ("a", "A"):
                self.apply_live()
            elif k in ("u", "U"):
                self.lines, self.colors, self.pal, self.named = parse(self.path)
                self.sel = min(self.sel, len(self.colors) - 1)
                self.dirty = False
                self.msg = "reverted to saved file"


def main():
    if len(sys.argv) < 2:
        print("usage: palette.py <ghostty-file> [theme]", file=sys.stderr)
        return 2
    path = sys.argv[1]
    theme = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(os.path.dirname(path))
    state = os.environ.get("OMACASE_STATE",
                           os.path.expanduser("~/.local/state/omacase"))
    try:
        with open(os.path.join(state, "theme")) as f:
            active = f.read().strip()
    except OSError:
        active = ""
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        print("omacase palette needs an interactive terminal.", file=sys.stderr)
        return 1
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        write(CSI + "?1049h" + CSI + "?25l")  # alt screen, hide cursor
        Editor(path, theme, active).run()
    finally:
        write(CSI + "?25h" + CSI + "?1049l")  # show cursor, leave alt screen
        sys.stdout.flush()
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
    return 0


if __name__ == "__main__":
    sys.exit(main())
