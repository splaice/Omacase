#!/usr/bin/env python3
"""Build home/Library/Fonts/OmacaseIcons.ttf — omacase's one-glyph icon font.

Ships "Clawd" (Claude Code's pixel-art crab mascot) at U+100000, a plane-16
private-use codepoint no Nerd Font touches. SketchyBar labels render with
JetBrainsMono Nerd Font; CoreText's system-wide font fallback finds this font
for the unmapped codepoint, so the crab drops into a label string like any
other glyph and tints with the theme's muted/accent colors. In bash 3.2 the
codepoint is the byte escape $'\\xf4\\x80\\x80\\x80' (see sketchybarrc).

Geometry is measured, rectangle for rectangle, from the 400x400 Clawd PNG at
https://dashboardicons.com/icons/clawd, scaled to fill the 1000-unit em width
and centered vertically. Eyes are reversed-winding contours (knockouts).

Regenerate with:  python3 assets/fonts/build_omacase_icons.py
(needs fonttools: `pip3 install fonttools` or `brew install fonttools`)
"""
import pathlib

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

FAMILY = "Omacase Icons"
UPM = 1000
ADVANCE = 1050
# JetBrainsMono Nerd Font's MDI icons and digits all center on y=360 (e.g.
# md-console spans -15..735, digit three -10..730). Matching that keeps the
# crab on the same optical line as its neighbors in a label string.
ICON_CENTER_Y = 360

# (x0, y0, x1, y1) in source-PNG pixels, y down; eyes knock out of the body.
CLAWD = {
    "body":  (72, 91, 331, 276),
    "eye_l": (107, 119, 141, 152),
    "eye_r": (261, 119, 295, 152),
    "arm_l": (12, 152, 72, 215),
    "arm_r": (331, 152, 389, 215),
    "leg1":  (72, 276, 107, 344),
    "leg2":  (136, 276, 170, 344),
    "leg3":  (231, 276, 264, 344),
    "leg4":  (294, 276, 331, 344),
}
BBOX = (12, 91, 389, 344)  # content bounds in source pixels


def clawd_glyph():
    scale = UPM / (BBOX[2] - BBOX[0])
    # oy positions the content so its vertical center lands on ICON_CENTER_Y
    oy = UPM - ICON_CENTER_Y - (BBOX[3] - BBOX[1]) * scale / 2
    pen = TTGlyphPen(None)
    for name, (x0, y0, x1, y1) in CLAWD.items():
        # source y is down, font y is up: top edge maps to the larger font y
        fx0, fx1 = (x0 - BBOX[0]) * scale, (x1 - BBOX[0]) * scale
        fy1, fy0 = UPM - ((y0 - BBOX[1]) * scale + oy), UPM - ((y1 - BBOX[1]) * scale + oy)
        corners = [(fx0, fy0), (fx1, fy0), (fx1, fy1), (fx0, fy1)]
        if name.startswith("eye"):  # opposite winding = hole (nonzero fill)
            corners.reverse()
        pen.moveTo(corners[0])
        for pt in corners[1:]:
            pen.lineTo(pt)
        pen.closePath()
    glyph = pen.glyph()
    glyph.recalcBounds(None)
    return glyph


def main():
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder([".notdef", "crab.clawd"])
    fb.setupCharacterMap({0x100000: "crab.clawd"})
    glyph = clawd_glyph()
    fb.setupGlyf({".notdef": TTGlyphPen(None).glyph(), "crab.clawd": glyph})
    fb.setupHorizontalMetrics({".notdef": (ADVANCE, 0),
                               "crab.clawd": (ADVANCE, glyph.xMin)})
    fb.setupHorizontalHeader(ascent=800, descent=-220)
    fb.setupOS2(sTypoAscender=800, sTypoDescender=-220,
                usWinAscent=800, usWinDescent=220)
    fb.setupNameTable({"familyName": FAMILY, "styleName": "Regular",
                       "fullName": FAMILY, "psName": FAMILY.replace(" ", "")})
    fb.setupPost()

    out = pathlib.Path(__file__).resolve().parents[2] / "home/Library/Fonts/OmacaseIcons.ttf"
    out.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(out))
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
