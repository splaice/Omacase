# omacase — ranger colorscheme. Extends ranger's stock default and only recolors
# directories to magenta (ANSI 5) to match omacase's eza/ls. Everything else
# inherits the default's ANSI assignments, so the UI tracks the active terminal
# theme (techno-viking and friends) with no per-theme files.
#
# IMPORTANT: ranger uses the class named `Scheme` if present; otherwise it grabs
# the FIRST ColorScheme subclass in the module — which would be the imported base
# (Default), leaving directories blue. So the class MUST be named `Scheme`, and
# we import the base via the module to keep `Default` out of this namespace.
from __future__ import absolute_import, division, print_function

import ranger.colorschemes.default as default_scheme
from ranger.gui.color import magenta, bold


class Scheme(default_scheme.Default):
    progress_bar_color = magenta

    def use(self, context):
        fg, bg, attr = super(Scheme, self).use(context)

        # Directories → magenta (the default uses blue). Leave marked/selected
        # rows alone so the selection highlight still reads clearly.
        if context.directory and not context.marked and not context.selected:
            if context.in_browser:
                fg = magenta
                attr |= bold
            elif context.in_titlebar:
                fg = magenta

        return fg, bg, attr
