# omacase — ranger colorscheme. Extends ranger's stock "default" and only
# recolors directories to magenta (ANSI 5), matching omacase's eza/ls. Everything
# else inherits the default's sensible ANSI assignments, so the whole UI tracks
# the active terminal theme (techno-viking and friends) with no per-theme files.
from __future__ import absolute_import, division, print_function

from ranger.colorschemes.default import Default
from ranger.gui.color import magenta, bold


class Omacase(Default):
    progress_bar_color = magenta

    def use(self, context):
        fg, bg, attr = super(Omacase, self).use(context)

        # Directories → magenta (the default uses blue). Leave marked/selected
        # rows alone so the selection highlight still reads clearly.
        if context.directory and not context.marked and not context.selected:
            if context.in_browser:
                fg = magenta
                attr |= bold
            elif context.in_titlebar:
                fg = magenta

        return fg, bg, attr
