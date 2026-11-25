# Omacase key reference

Omacase keeps macOS's own window management and adds no global window-manager
shortcuts.

## macOS

| Keys | Action |
|---|---|
| `⌘ Space` | Sol (launcher) |
| `⌘ Tab` | macOS app switcher |
| `⌃⌘ Space` | Emoji & Symbols |

[Sol](https://sol.ospfranco.com/) is the launcher. Omacase turns off Spotlight's
`⌘ Space` and `⌥⌘ Space` shortcuts, and you choose `⌘ Space` in Sol's onboarding
(Sol starts on `⌥ Space`). Spotlight indexing and Finder search keep working.
Sol also handles window snapping. Run `omacase menu` for the Omacase TUI, or
bind any `omacase` subcommand to a shortcut in the tool of your choice.

## Terminal

| Keys | Action |
|---|---|
| `⌃ Esc` | Ghostty quick terminal (drop-down from the top, from any app) |

The quick terminal works while Ghostty is running and needs Ghostty in
Accessibility. Other Ghostty, shell, and editor bindings are independent of
Omacase. Use
`omacase terminal` when a script needs a new Ghostty window and
`omacase files` for the optional yazi popup.
