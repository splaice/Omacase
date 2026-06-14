# omacase — ranger colorscheme. A thin pass-through of ranger's stock default,
# whose ANSI colors already track the active terminal theme (blue directories,
# cyan links, …) via the palette. We deliberately DON'T recolor anything.
#
# An earlier version forced directories to magenta (ANSI 5) to match techno-viking
# — but that bled the magenta accent into EVERY theme (matte-black, gruvbox, …),
# since it pinned the color regardless of which theme was active. The default is
# already theme-adaptive, so this just inherits it.
#
# ranger picks the class named `Scheme` if present; else the first ColorScheme
# subclass in the module (the imported Default). We name it `Scheme` and import
# the base via the module so the choice stays unambiguous.
from __future__ import absolute_import, division, print_function

import ranger.colorschemes.default as default_scheme


class Scheme(default_scheme.Default):
    pass
