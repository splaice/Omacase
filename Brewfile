# frozen_string_literal: true

# omacase Brewfile — the opinionated package set. `brew bundle` is idempotent.
# Edit, then `omacase update` (or `brew bundle`) to converge.

# --- The "make Mac behave" set ---------------------------------------------
# Launcher is Sol (⌘Space) — a fast, free, open-source launcher / command
# palette (app search, clipboard history, emoji, window snapping, scratchpad).
# macos/defaults.sh releases ⌘Space from Spotlight so Sol can take it; pick
# "⌘ Space" in Sol's onboarding. Spotlight indexing/search still works.
cask "sol"               # launcher — replaces Spotlight on ⌘Space
cask "keepingyouawake"   # keep-awake toggle in the menu bar (wraps caffeinate)
# Menu bar is stock macOS — no third-party menu-bar manager.

# --- Terminal & shell -------------------------------------------------------
cask "ghostty"           # native GPU terminal
brew "starship"          # prompt
brew "eza"               # ls
brew "bat"               # cat
brew "fd"                # find
brew "ripgrep"           # grep
brew "fzf"               # fuzzy finder
brew "btop"              # full terminal system monitor
brew "yazi"              # TUI file manager (`omacase files` opens it as an optional popup)
brew "git-delta"         # git diffs
brew "herdr"             # agent-aware multiplexer; sessions survive disconnect (`herdr --remote` for SSH)
brew "zsh-completions"   # extra completion defs beyond zsh's bundled set (wired in dot_zshrc)
brew "glow"              # markdown rendered in the terminal (read READMEs where you are)
brew "mole"              # `mo` — deep clean + thorough app uninstaller (`omacase extras mole`; `mo clean --dry-run` previews)
brew "jq"                # JSON wrangling
brew "fastfetch"         # branded system summary (`omacase menu` → About); config in home/

# --- Editor & dev -----------------------------------------------------------
brew "neovim"            # + LazyVim (seeded via dotfiles) — the editor
brew "uv"                # fast Python package/tool manager (hosts mlx-lm for the planned local LLM)
brew "gh"                # GitHub CLI
brew "just"              # command runner (justfiles)

# --- AI coding & local LLM --------------------------------------------------
# Everything here comes from Homebrew. (Claude Code and the Grok CLI self-manage
# via their own installers — Grok can be explicitly enabled with
# OMACASE_INSTALL_GROK=1 — so neither is declared here.)
cask "codex"             # OpenAI Codex CLI (official Rust binary; depends on ripgrep)
brew "pi-coding-agent"   # pi — pi.dev coding agent (homebrew-core; brings its own node)
brew "opencode"          # opencode — terminal AI coding agent (homebrew-core)

# --- Networking -------------------------------------------------------------
# Tailscale is what makes the remote half of herdr usable: `herdr --remote
# <host>` needs the box reachable from anywhere, and the herdr server keeps the
# agent running there after the laptop disconnects.
cask "tailscale-app"     # mesh VPN / private network

# --- Opinionated applications -----------------------------------------------
# Omacase installs these and offers optional CLI/menu launch helpers.
cask "spotify"           # music (Apple Music is stock)
cask "obsidian"          # notes / knowledge base
# Markdown Preview is the desktop *reader* for .md: native AppKit/WebKit, MIT,
# opens instantly, offers to be the default .md handler, and bundles a Quick
# Look extension (Finder spacebar / Spotlight) plus the `mdp` CLI — Homebrew
# links it, so `mdp README.md` / `mdp .` work from any shell. glow (above)
# remains the in-terminal reader; this is the window you open files in.
cask "markdown-preview"  # Markdown viewer + Quick Look extension + `mdp` CLI (not an editor)
cask "1password"         # password manager
cask "todoist-app"       # tasks

# Messaging. Native apps rather than browser tabs: these want background
# notifications, and the desktop clients carry features the web versions do not.
cask "discord"          # Discord — community & voice chat
cask "signal"           # Signal — private messaging
cask "telegram"         # Telegram — messaging
cask "whatsapp"         # WhatsApp — messaging (self-updates; brew upgrade skips it)
# --- Dictation --------------------------------------------------------------
cask "fluidvoice" # offline voice-to-text (local model); needs Mic + Accessibility

# --- Tooling ----------------------------------------------------------------
brew "gum"               # TUI for `omacase menu`
brew "terminal-notifier" # reliable native notifications for `omacase notify` (osascript's are flaky)
# (Omacase manages its own dotfiles via symlinks — no chezmoi dependency.)

# --- Fonts ------------------------------------------------------------------
# Ghostty's fallback chain, in order (home/dot_config/ghostty/config).
cask "font-maple-mono-nf"    # Maple Mono NF — main terminal font + Nerd Font icons
cask "font-juliamono"        # JuliaMono — fills in symbols Maple lacks
cask "font-noto-color-emoji" # Noto Color Emoji — emoji
# --- Browsers ---------------------------------------------------------------
# Chrome is the daily/default browser, the web-dev reference engine (and where
# Claude in Chrome runs). Safari stays stock. Only the stable channel ships —
# a default set has no business installing two channels of one browser.
cask "google-chrome"    # Chrome — daily browser