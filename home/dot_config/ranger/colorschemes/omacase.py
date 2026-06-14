# omacase — ranger colorscheme. A thin pass-through of ranger's stock Default,
# whose file-list colors are ANSI (directories=blue, links=cyan, executables=
# green, …) and therefore track whichever omacase theme is active: Ghostty swaps
# the 16 ANSI colors per theme, so each theme renders in its own hues — and
# greyscale themes (white, vantablack) render monochrome. We add no colors of our
# own; an earlier version pinned magenta and bled it into every theme.
#
# ranger picks the class named `Scheme` if present, else the first ColorScheme
# subclass in the module; we name it `Scheme` to stay unambiguous.
from __future__ import absolute_import, division, print_function

import ranger.colorschemes.default as default_scheme


class Scheme(default_scheme.Default):
    pass
